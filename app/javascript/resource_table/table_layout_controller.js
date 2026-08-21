import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"
import { sendLayout } from "./layout_command.js"

// Drag gestures for the collection table: column resize and header reorder.
// Owns no persisted layout state and builds no display HTML — transient drag state only.
// Every gesture commits via a plain fetch PATCH; nothing re-renders. Only the picker reloads the page.
export default class extends Controller {
    static targets = ["resizer", "headerRow"]
    static values  = { url: String, key: String }

    connect() {
        if (this.hasHeaderRowTarget) {
            this.sortable = Sortable.create(this.headerRowTarget, {
                draggable: "th",
                handle: ".th-grip",
                animation: 120,
                onEnd: this.onReorder.bind(this)
            });
        }
        this._onMove = this.onResizeMove.bind(this);
        this._onUp = this.onResizeUp.bind(this);
        this.initColumnLayout();
    }

    disconnect() {
        if (this.sortable) this.sortable.destroy();
        if (this._layoutObserver) { this._layoutObserver.disconnect(); this._layoutObserver = null; }
        this.endResizeListeners();
    }

    // Initial column layout, run once the table actually has a width: content-fit
    // the autosize columns, then solidify the flex column. A hidden table (inactive
    // tab) measures 0 wide, so both steps defer via a single ResizeObserver until it
    // first has a real width.
    initColumnLayout() {
        if (!this.hasHeaderRowTarget) return;
        const run = () => {
            if (this.headerRowTarget.getBoundingClientRect().width <= 0) return false;
            this.autosizeColumns();
            this.solidifyFlexColumn();
            return true;
        };
        if (run()) return;
        this._layoutObserver = new ResizeObserver(() => {
            if (run()) { this._layoutObserver.disconnect(); this._layoutObserver = null; }
        });
        this._layoutObserver.observe(this.element);
    }

    // Size each un-declared, non-flex column (server-flagged data-autosize) to its
    // content on first render — measure with fitWidth (header + visible cells,
    // clamped 40–800), set its <col> width, and persist. Once persisted,
    // Table#build (`autosize: !flex && width.nil?`) stops flagging it on the next
    // full page load, not via an automatic re-render — so this runs once per table.
    autosizeColumns() {
        const autoThs = Array.from(this.headerRowTarget.querySelectorAll("th[data-autosize]"));
        if (!autoThs.length) return;
        const ths = Array.from(this.headerRowTarget.children);
        const cols = Array.from(this.element.querySelectorAll("colgroup col"));
        const widths = {};
        autoThs.forEach((th) => {
            const idx = ths.indexOf(th);
            const col = cols[idx];
            if (!col) return;
            const w = this.fitWidth(idx, th, col);
            col.style.width = w + "px";
            th.removeAttribute("data-autosize");
            if (th.dataset.column) widths[th.dataset.column] = w;
        });
        if (Object.keys(widths).length) this.sendCommand({ command: "set_column_widths", widths });
    }

    // The flex column (a data column, NOT the always-present dummy spacer) renders
    // with NO width so it fills the table on initial paint. Freeze that filled width
    // into its <col>, drop the flex flag so it now resizes like any other column,
    // and hand the slack to the dummy spacer so resizing stays clean (a single
    // unsized absorber). Purely visual — the width is NOT persisted, so a later
    // re-render recomputes the fill for the current viewport; only an explicit drag
    // persists (see onResizeUp) and then the server renders it fixed
    // (Table#build's `flex` no longer holds once the column has a persisted width).
    // Synchronous: initColumnLayout only calls this once the table has a real width.
    solidifyFlexColumn() {
        // [data-column] distinguishes the real flex column from the spacer th
        // (which is always data-flex but carries no data-column).
        const flexTh = this.headerRowTarget.querySelector("th[data-flex][data-column]");
        if (!flexTh) return;
        const width = flexTh.getBoundingClientRect().width;
        if (width <= 0) return;
        const ths = Array.from(this.headerRowTarget.children);
        const col = Array.from(this.element.querySelectorAll("colgroup col"))[ths.indexOf(flexTh)];
        if (col) col.style.width = Math.round(width) + "px";
        flexTh.removeAttribute("data-flex");
        // Release the spacer (rendered zero-width while the flex column was filling)
        // so it absorbs the slack from now on.
        const spacerCol = this.element.querySelector("colgroup col.col-flex-spacer");
        if (spacerCol) spacerCol.style.width = "";
    }

    // ---- resize ----
    resizerTargetConnected(el) {
        el.addEventListener("mousedown", this.onResizeStart.bind(this));
        el.addEventListener("dblclick", this.onAutofit.bind(this));
    }

    // Double-click the resize handle: size the column so its widest on-screen
    // content (header + visible body cells) fits, then persist like a drag.
    onAutofit(event) {
        event.preventDefault();
        event.stopPropagation();
        const th = event.currentTarget.closest("th");
        if (!th) return;

        const ths = Array.from(this.headerRowTarget.children);
        const cols = Array.from(this.element.querySelectorAll("colgroup col"));
        const idx = ths.indexOf(th); // header <th> and <col> are index-aligned
        const col = cols[idx];
        if (idx < 0 || !col) return;

        // Pin every non-flex column to its current width so the table doesn't
        // rebalance while we measure/set this one.
        const current = ths.map(t => t.getBoundingClientRect().width);
        ths.forEach((t, i) => {
            if (cols[i] && !t.hasAttribute("data-flex")) cols[i].style.width = current[i] + "px";
        });

        col.style.width = this.fitWidth(idx, th, col) + "px";

        // Persist every column (mirror onResizeUp), skipping the flex column.
        const widths = {};
        ths.forEach((t) => {
            const name = t.dataset.column;
            if (name && !t.hasAttribute("data-flex")) widths[name] = Math.round(t.getBoundingClientRect().width);
        });
        if (Object.keys(widths).length) this.sendCommand({ command: "set_column_widths", widths });
    }

    // Natural content width of a column: shrink the <col> so every cell overflows,
    // then read scrollWidth (full content incl. padding — ignores the ellipsis
    // truncation) across the header + body cells. Clamped to a sane range.
    fitWidth(idx, th, col) {
        const prev = col.style.width;
        col.style.width = "1px";
        void this.element.offsetWidth; // reflow so the shrink takes effect
        const rows = this.element.querySelectorAll("tbody tr");
        // Horizontal padding of this column's body cells (constant per column). A
        // nested child reports its content-box scrollWidth, which excludes the
        // <td>'s padding — add it back so the child measurement lines up with a
        // plain cell's td.scrollWidth (which already includes it). Measured once.
        let pad = 0;
        for (const tr of rows) {
            const c = tr.children[idx];
            if (c && c.children.length) {
                const cs = getComputedStyle(c);
                pad = (parseFloat(cs.paddingLeft) || 0) + (parseFloat(cs.paddingRight) || 0);
                break;
            }
        }
        let max = this.contentWidth(th, 0);
        rows.forEach((tr) => {
            const cell = tr.children[idx];
            if (cell) max = Math.max(max, this.contentWidth(cell, pad));
        });
        col.style.width = prev;
        return Math.min(Math.max(max + 12, 40), 800);
    }

    // The natural content width of a cell. A plain cell's text sits directly in the
    // (overflow:hidden) <td>, so its own scrollWidth is right. An EDITABLE cell nests
    // its text in a `.cell-display` span that has its OWN overflow:hidden — that
    // hides the text from the <td>'s scrollWidth (it collapses to ~the column width),
    // so also take the widest child's scrollWidth PLUS the cell padding (`pad`) so
    // it's measured in the same frame as a plain td.scrollWidth. Cheap (one level;
    // the wrappers we clip are direct children).
    contentWidth(cell, pad) {
        let w = cell.scrollWidth;
        for (const child of cell.children) w = Math.max(w, child.scrollWidth + pad);
        return w;
    }

    onResizeStart(event) {
        event.preventDefault();
        event.stopPropagation();
        const handle = event.currentTarget;
        const th = handle.closest("th");

        // Freeze EVERY column at its current rendered width before dragging.
        // The table is `table-layout: fixed; width: max-content`, so pinning a
        // single column's width makes the layout redistribute all the other
        // (still-unpinned) columns and recompute max-content — the visible
        // "jump" on grab. Pinning them all first (a visual no-op) isolates the
        // drag to the one column. Header <th>s and <col>s are index-aligned
        // (both include the leading checkbox column when present).
        const ths = Array.from(this.headerRowTarget.children);
        const cols = Array.from(this.element.querySelectorAll("colgroup col"));
        // Read ALL current widths first, THEN write — otherwise each write
        // reflows the table and the next read sees an already-shifted width,
        // cascading into a jump. Skip the flex column ([data-flex]): leaving it
        // unsized lets it absorb the resized column's delta.
        const widths = ths.map(t => t.getBoundingClientRect().width);
        ths.forEach((th, i) => {
            if (cols[i] && !th.hasAttribute("data-flex")) cols[i].style.width = widths[i] + "px";
        });

        this.resizing = {
            column: handle.dataset.column,
            startX: event.pageX,
            startWidth: th.getBoundingClientRect().width,
            moved: false
        };
        document.addEventListener("mousemove", this._onMove);
        document.addEventListener("mouseup", this._onUp);
        this.element.classList.add("is-resizing");
    }

    onResizeMove(event) {
        if (!this.resizing) return;
        const width = Math.max(40, Math.round(this.resizing.startWidth + (event.pageX - this.resizing.startX)));
        this.resizing.width = width;
        this.resizing.moved = true;
        const col = this.colFor(this.resizing.column);
        if (col) col.style.width = width + "px";
    }

    onResizeUp() {
        if (!this.resizing) return;
        this.endResizeListeners();
        const moved = this.resizing.moved;
        this.resizing = null;

        // A no-move mousedown/up (a plain click, or the two clicks that make up a
        // double-click → autofit) must NOT persist — otherwise it races the
        // autofit command with the old widths and clobbers it.
        if (!moved) return;

        // Persist EVERY column's current width, not just the dragged one. All
        // columns are pinned to px during the drag; persisting them all means
        // the next full navigation reproduces the exact drag-end layout instead
        // of letting the un-persisted columns revert to ratio widths and re-settle.
        const widths = {};
        Array.from(this.headerRowTarget.children).forEach((th) => {
            const name = th.dataset.column;
            // Don't persist the flex column — it stays unsized and absorbs slack.
            if (name && !th.hasAttribute("data-flex")) widths[name] = Math.round(th.getBoundingClientRect().width);
        });
        if (Object.keys(widths).length) this.sendCommand({ command: "set_column_widths", widths });
    }

    endResizeListeners() {
        document.removeEventListener("mousemove", this._onMove);
        document.removeEventListener("mouseup", this._onUp);
        this.element.classList.remove("is-resizing");
    }

    // Maps a column id to its <col> element. The colgroup mirrors the FULL
    // header row 1:1 (leading select-checkbox col, data cols, trailing
    // row-actions col all in the same order), so index into the full header
    // children rather than the data-only subset — a naive
    // `cols.length - ths.length` offset silently mis-maps when there's a
    // trailing actions col (the resize lands on the neighbouring column).
    colFor(column) {
        const ths = Array.from(this.headerRowTarget.children);
        const idx = ths.findIndex(th => th.dataset.column === column);
        if (idx < 0) return null;
        const cols = this.element.querySelectorAll("colgroup col");
        return cols[idx] || null;
    }

    // ---- reorder ----
    onReorder(event) {
        if (event && event.oldIndex === event.newIndex) return;
        const visible = Array.from(this.headerRowTarget.querySelectorAll("th[data-column]"))
            .map(th => th.dataset.column);
        this.sendCommand({ command: "set_column_layout", visible });
    }

    // ---- shared command sender ----
    // urlValue/keyValue live on this.element (the scroll wrapper carrying
    // data-controller), never on a target. sendLayout (layout_command.js)
    // builds the payload and PATCHes it; console.warn logs a rejection or
    // failure since there is no this.log() here.
    sendCommand(body) {
        sendLayout(this.urlValue, this.keyValue, body)
    }
}
