# ResourceTable

A Rails engine that renders a `ResourceCore::BaseResource` as a resizable,
reorderable, sortable, column-pickable HTML table — the table counterpart to
[`resource_form`](https://github.com/bduc/resource_form). It reads the same
`*Resource` classes a form renders, adds one more namespace to the field spec
(`index:`), and contributes no model, no route and no idea of who "the
current user" is: a host app wires those three things in.

Given a resource:

```ruby
class BookResource < ApplicationResource
  field :title,  index: { sortable: true, width: 320, label: "Title" }
  field :author, index: { sortable: "authors.name", label: "Author" }
  field :price,  index: { label: "Price" }
  field :isbn,   index: { default: false }     # pickable, hidden by default
  field :notes,  index: false                  # never a column at all
end
```

a view renders:

```erb
<%= resource_table_for @books, presenter: BookTablePresenter do |t| %>
  <% t.cell(:price) { |book| number_to_currency(book.price) } %>
  <% t.actions { |book| link_to "Edit", edit_book_path(book) } %>
<% end %>
```

`t.cell(:price)` only fires for a column the resource actually declares —
`price` has to appear in `BookResource` above (it does, as an `index:`
column) or the block never runs; see "Presenter and block resolution order"
below for the full lookup order a cell goes through.

and gets a table with a drag handle per header, a drag handle on each column's
right edge to resize it, a "columns" picker for anything declared `index:`
(rendered immediately below the table by default — see `picker:` and
`resource_table_picker_for` below for placing it elsewhere, e.g. a card
header), and — if the resource declares one — sortable headers. Every
gesture PATCHes a layout endpoint the host provides; nothing here re-renders
the page.

## The `index:` namespace

A field reaches the table only through its `index:` option, and that option
has three states. The semantics are opt-**out**, not opt-in: `Table#specs`
rejects only fields where `spec[:index] == false`, so a field with no
`index:` at all is a **visible default column**, exactly like one with a
declared `index: { ... }`.

- **`index: { ... }`** (a Hash, however sparse), **or no `index:` at all** —
  the field is a column, offered in the picker, **and** part of the coded
  default column set: the columns a first-time visitor sees before ever
  touching the layout.
- **`index: { default: false, ... }`** — the field is a column and is
  offered in the picker, but is **not** part of the default set. It only
  ever appears once a user's stored layout names it (by picking it, or by a
  layout written some other way).
- **`index: false`** — the field is not a column at all. It never reaches
  the picker and can never be resurrected by a stored layout (a stale
  `visible` array naming it is silently filtered against the resource's
  current declared fields on every read).

A third conversion trusting the opposite reading — that leaving `index:` off
means "not a column" — ships a table exposing every model attribute by
default. If a field genuinely has no business in a table, say so explicitly
with `index: false`.

Declaration order is column order for both the default set and the picker —
`field`'s delete-then-reinsert semantics mean a later `field :x, index: {...}`
call both applies the option and moves `:x` to that position, without
disturbing whatever `as:`/`class_name:`/etc. an earlier call set.

### The rest of the `index:` options

Beyond `sortable:` and `default:` (both covered on their own above), six more
keys are registered (`ResourceCore.register_namespace :index, %i[sortable
width align link label format default flex]`) and read by `Column`:

- **`width:`** — the column's pixel width on first render. Only a starting
  point: a user's drag-resize persists to the stored layout and wins over
  this from then on (`Table#build`: `widths[name] || index[:width]`).
- **`align:`** — `:right` or `:center` right/center-aligns the header and
  cell text (e.g. a numeric `id` column); anything else (including absent)
  left-aligns.
- **`link:`** — `:self` makes the generic cell partial link its text to the
  record's own show page (`Presenter#record_url`), falling back to plain
  text if no route resolves for that model/action.
- **`label:`** — the header text. Falls back to `index[:label]`, then
  `spec[:label]`, then the model's `human_attribute_name`, then a humanized
  field name — in that order (`Column#label`).
- **`format:`** — handed to `ResourceCore::Value.display` for the generic
  cell, winning over whatever format the field's own (non-`index`) spec set.
- **`flex:`** — the one slack absorber among the visible columns: it grows
  to fill leftover width rather than autosizing to its content. A
  **persisted** width (one a user has actually dragged) revokes it —
  `Table#build`'s `flex = index[:flex] == true && widths[name].nil?` — but a
  merely *declared* `width:` does not, so declaring `width:` and `flex: true`
  on the same field leaves both true at once. That combination is a
  developer error the engine does not resolve for you; pick one.

## `sortable:` — `true`, or a string, and why

`sortable: true` works for any field that is a bare column on the resource's
own table. Anything else — a joined column, a computed value, an aliased
expression — needs `sortable: "<sql expression>"` instead:

```ruby
field :author, index: { sortable: "authors.name", label: "Author" }
```

The reason is not cosmetic. The index query underneath a table like this
typically runs `SELECT DISTINCT` (a record joined to a has-many association
would otherwise repeat once per joined row), and PostgreSQL requires every
`ORDER BY` expression to appear in the `SELECT` list under `DISTINCT`. A bare
column that exists only on the base table is already covered by `SELECT
base_table.*` and needs nothing further. A column reached only through a
join — `authors.name` when the select list is `books.*` — is not, and
ordering by it raises `PG::InvalidColumnReference` outright. `sortable:`
being a string is the escape hatch: the resource declares the exact
expression to order by, and the host adds that same expression to the select
list (typically as an alias) precisely when a request sorts on it.

**The tempting fix — `SELECT books.*, authors.name AS sort_author` — is
wrong, and it does not fail loudly.** It satisfies Postgres, so nothing
errors. What it actually does is apply `DISTINCT` to the *pair*
`(books.*, authors.name)` rather than to `books.id` alone: a book with two
authors now produces two rows instead of one, silently, while a `COUNT
(DISTINCT books.id)` pagination total stays correct — so the count and the
rendered rows disagree, and enough duplication accumulates that rows past
the last "page" become unreachable. This project shipped that exact bug and
it was rated Critical on review. The safe version is a **correlated
subquery** that is guaranteed to yield exactly one scalar per base row
(`(SELECT authors.name FROM authors WHERE authors.id = books.author_id ORDER
BY ... LIMIT 1) AS sort_author`), not a join column pulled into the select
list. If your sort key isn't a plain join either — say, "the currently
active one of several associated rows" — make sure the subquery's own
ordering matches whatever rule decides which associated row the *cell*
displays; a subquery that resolves ties differently than the presenter
displays them sorts correctly by a value the user never sees.

## Presenter and block resolution order

A column's cell content resolves in one order, checked once per cell:

1. **A call-site block** — `t.cell(:price) { |book| ... }` at the
   `resource_table_for` call.
2. **A `cell_<name>` method** on the presenter class.
3. **`ResourceCore::Value.display`** — the same formatting `resource_form`
   uses for its own value rendering, driven by the field's spec.

`Presenter#overridden?(column)` answers whether (1) or (2) applies, and the
two specialised cell partials this engine ships (`_boolean`, `_lookup_one`)
both defer to it *before* rendering their own markup — a block or a
`cell_<name>` always wins over the boolean checkmark or the lookup's link,
never merely for columns using the generic `_cell` partial. Get this
backwards (check the block only from the generic partial) and a column using
a specialised type silently ignores an override the call site wrote in good
faith.

`Presenter` is deliberately not a component and holds no markup itself: it
takes a `view_context:` and answers `cell(column, record)` and
`record_url(record)`, delegating anything else (`link_to`, route helpers,
`t`) to the view via `method_missing`/`respond_to_missing?`. That is what
lets a plain ERB partial and, eventually, a ViewComponent both call it
unchanged.

## The markup contract

The partials and `table_layout_controller.js` agree on a specific DOM shape:
the `<colgroup>` mirrors the header row **1:1**, including the always-present
trailing spacer `<col>` and the pinned actions `<col>` when there is one —
because the controller maps a `<th>` to its `<col>` by *index into the full
header row*, not by counting only data columns. Get that alignment wrong
(most easily: forget the spacer, or reorder actions before data columns) and
resizing lands on the neighbouring column instead of the one being dragged,
silently — the DOM manipulation still runs, it just moves the wrong node.

This is why the engine ships partials, **not CSS**: its own build has no way
to reach into a host app's Tailwind pipeline from a sibling git checkout, so
the utility classes a host already has cannot cover what these partials
need. **A host must ship the structural CSS itself.** The rules Tailwind's
utilities cannot express — verified against the shipped partials, this
exact block, appended under `@layer components` in the host's stylesheet:

```css
/* resource_table — structural rules the utility classes cannot express.
   The engine ships partials, not CSS: its build cannot reach into this app's
   Tailwind pipeline from a sibling git checkout. The engine's README states
   this contract and its rendering test asserts the class names below are
   emitted, so the two cannot drift silently. */
@layer components {
  .resource-table {
    table-layout: fixed;
    width: 100%;
  }

  /* Always-present slack absorber: borderless and padless so it reads as empty
     space. Never resized or reordered — it carries no data-column. */
  .resource-table .col-flex-spacer {
    padding: 0;
    border: 0;
  }

  /* Pinned actions column: stuck to the right edge of the scrollport so row
     actions stay reachable however wide or scrolled the table is. Needs its own
     background — it paints over columns sliding underneath. */
  .resource-table .col-row-actions {
    width: 5.5rem;
    white-space: nowrap;
    text-align: right;
    position: sticky;
    right: 0;
    z-index: 1;
    background: var(--color-base-100);
    box-shadow: inset 1px 0 0 var(--color-base-300);
  }
  .resource-table thead th.col-row-actions { z-index: 3; }

  /* position: sticky creates a containing block for absolutely-positioned
     children, so .th-resizer anchors to the th's right edge AND the header
     pins during vertical scroll. This rule is load-bearing, not decoration. */
  .resource-table thead th {
    position: sticky;
    top: 0;
    z-index: 2;
    background: var(--color-base-200);
    user-select: none;
  }

  .resource-table thead th .th-grip {
    cursor: grab;
    opacity: 0;
    transition: opacity 0.12s;
    margin-right: 0.25rem;
  }
  .resource-table thead th:hover .th-grip { opacity: 0.5; }

  .resource-table thead th .th-resizer {
    position: absolute;
    top: 0;
    right: 0;
    width: 6px;
    height: 100%;
    cursor: col-resize;
    z-index: 3;
  }

  .resource-table thead th .th-sort:hover { text-decoration: underline; }
  .resource-table thead th .th-sort.sort-active { font-weight: 600; }

  .resource-table td {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .resource-table-scroll.is-resizing {
    cursor: col-resize;
    user-select: none;
  }
}
```

A host that skips this does not get an error — it gets a table that mostly
looks right until someone drags something, at which point resizing, the
sticky header, and the pinned actions column all misbehave in ways that
read as JS bugs but are missing CSS.

## The shared-singleton rule

Every runtime JS dependency the engine and the host both use — Stimulus
today, `sortablejs` for reordering, anything stateful added later (Turbo
especially) — **must resolve to the host's own installed copy**, not the
engine's. The engine ships its own `package.json` with these as
dependencies (so its own test suite can run standalone), and a bundler that
walks node_modules upward from the *importing file* will happily find the
engine's copy first, because the engine's source lives outside the host's
own directory tree. Left unaliased, a host bundling with esbuild ends up
with two separate copies of the same package in one bundle — the engine's
controllers built on one `Controller` base class, the host's `Application`
built on the other. With esbuild specifically:

```js
alias: {
  "@hotwired/stimulus": `${process.cwd()}/node_modules/@hotwired/stimulus`,
  sortablejs: `${process.cwd()}/node_modules/sortablejs`
}
```

**Why this can fail silently, not loudly:** nothing about having two module
instances of the same package is a syntax or load error — both copies parse
and evaluate fine, and esbuild just gives the second one's colliding export
a renamed local (`Controller`, `Controller2`). Whether that duplication then
*breaks* anything depends entirely on whether either library keeps
realm-scoped state — an `instanceof` check against its own base class, a
module-scoped `Symbol()`, a private registry keyed by object identity — that
a same-named-but-different-object class from the other copy would fail. If
it does, a controller built from the "wrong" copy can be registered,
instantiated and never actually connect, and nothing raises: the code paths
involved are all optional/defensive by nature (a MutationObserver simply
doesn't fire a callback for something it doesn't recognise). That is what
makes it worth guarding against by construction rather than by testing for
it after the fact — a version bump to either package is exactly the kind of
change that can turn a currently-inert duplication into a silently broken
one, and there is no reliable way to assert "this duplication happens to be
harmless" as a permanent property.

Guard the assumption behind the alias, not the specific failure: a
grep for how many times a class gets declared in the built bundle is not
that guard (a renamed second declaration, or a minifier's own scheme, can
make the count come back however the grep's author hoped regardless of
whether the alias actually did its job). Inspect the bundler's own module
graph instead — esbuild's `metafile` lists, per output, the literal source
file each import resolved to; two different paths for the same package name
is the actual signal, not a string count in the output.

## No migrations, no routes, no authentication

The engine ships none of the three, on purpose — it does not get to decide
where a host's layouts live, what a host's URLs look like, or who a host
lets write to them. A host wires exactly four things:

- **`config.layout_store`** — anything answering `read(owner, key)` /
  `write(owner, key, layout)`. Two adapters ship for reference
  (`Stores::SettingsTable`, one row per `(owner, key)`; `Stores::JsonColumn`,
  one jsonb column holding every layout for an owner) behind one shared
  contract test module, so a third backing store only has to pass that
  contract, not reinvent the read/write shape.
- **`config.layout_url`** — where the Stimulus controllers PATCH a changed
  layout.
- **`config.owner_method`** — sent to the view to find the layout's owner
  (`current_user` by default; anything the host's session exposes works).
- **A controller action behind that URL, in the host, that validates the
  key before touching the store.** `ResourceTable.layout_resource_class(key)`
  is the single place a key string resolves to a constant — it returns the
  `ResourceCore::BaseResource` subclass named by a `<ResourceName>/index`
  shaped key, or `nil` for anything else — so call it in place of a second,
  unguarded `constantize` and treat a `nil` result as invalid. (`layout_key_
  valid?(key)` still exists as a plain yes/no wrapper around the same
  resolution, for callers that only need the boolean.) Reject the resource
  if it declares no fields (a resource with no model behind it, or a base
  class with nothing declared, still passes the shape check and would
  otherwise let a request write a row that stores nothing useful). The host
  also decides what `visible`/`widths` values are acceptable to persist
  (which field names are known, what a width may range over) — the engine
  does not sanitise payload contents for you, only the key.

## `sort_path:`

`resource_table_for`'s sort links default to
`url_for(request.query_parameters.merge(sort: ..., dir: ..., page: 1))`,
which resolves against the *current* controller/action. That default is
wrong in two real situations: more than one route maps to the same
controller action (a bare `root "books#index"` declared ahead of `resources
:books` makes the resolved URL flip between `/` and `/books` depending on
what Rails happens to pick), and rendering the same table from inside a
`turbo_stream` response written by a *different* action (a delete or update
action re-rendering the index fragment resolves sort links against itself,
producing a link to `DELETE /books/:id?sort=...` instead of the index).
Pass `sort_path:` explicitly whenever either applies:

```erb
<%= resource_table_for @books, presenter: BookTablePresenter, sort_path: books_path %>
```

`resource_table_for` also accepts an already-built `table:` (typically from
a controller that read `table.sort.order_clause` before querying), so the
view does not construct a second `Table` from a second layout-store read for
the same request.

## `picker:` and `resource_table_picker_for`

`resource_table_for` renders the "columns" picker immediately after the
table by default (`picker: true`) — the historical placement, so no existing
caller silently loses it. A bare ☰ button below the last row is easy to miss,
though, so pass `picker: false` to render the table without it, and call
`resource_table_picker_for` separately to place the picker wherever the
host's layout actually wants it — typically a card header, beside a "+"
button:

```erb
<div class="card-header flex justify-between items-center">
  <span>Books</span>
  <div class="flex items-center gap-2">
    <%= resource_table_picker_for presenter: BookTablePresenter, table: @table %>
    <%= link_to "+", new_book_path %>
  </div>
</div>
<%= resource_table_for @books, presenter: BookTablePresenter, table: @table, picker: false %>
```

`resource_table_picker_for` resolves `resource:`/`presenter:`/`key:`/
`layout:`/`table:` exactly as `resource_table_for` does — both funnel
through the same private resolution method — so the two agree on the same
key, and passing the identical `table:` to both, as above, guarantees one
`Table` and one layout-store read for the request. Called *without*
`table:`, `resource_table_picker_for` performs its own store read — fine for
a picker rendered on its own, but a caller that also calls
`resource_table_for` for the same collection should build the `Table` once
and pass that same `table:` to each.

The dropdown's alignment is placement-dependent: a right-aligned menu
belongs to a trigger sitting at a right edge (a card header) and overflows
off-screen hung off a trigger anywhere else (an earlier version of this
picker sat at a card's bottom-left, where the same right-aligned menu
rendered off the left edge of the viewport). `resource_table_picker_for`'s
`class:` option — merged onto the dropdown wrapper's class list in place of
the default — controls this, and defaults to `dropdown-end`.

## `wrapper_class:`

The scroll wrapper `_table.html.erb` renders around the `<table>` is
hardcoded to `overflow-x-auto resource-table-scroll` — enough for the table
to scroll horizontally, sitting inside whatever height its parent gives it
naturally. A host that wants that box bounded to a fixed height and
scrolling vertically too (a full-viewport index page, say) passes
`wrapper_class:`:

```erb
<%= resource_table_for @books, presenter: BookTablePresenter, wrapper_class: "overflow-y-auto min-h-0" %>
```

The classes are **appended**, never substituted — omit the option and the
wrapper renders exactly as it always has (`overflow-x-auto
resource-table-scroll`, nothing more), so every existing caller is
unaffected. This is also what unlocks `.resource-table thead th`'s
`position: sticky; top: 0`: sticky positioning resolves against the nearest
*scrolling* ancestor, and without a bounded, overflowing wrapper there is no
such ancestor for the header to pin against.

## The ViewComponent position

Nothing here is a component, and that is a decision, not an oversight.
`Table`, `Sort`, `Presenter` and the layout stores are entirely view-free:
`Table` takes a resource class, a layout hash and request params and
answers which columns, in what order, at what width, sorted how; `Presenter`
takes a `view_context` and answers cell content; neither one renders
anything itself. The only view-bound piece is the four ERB partials plus
their DaisyUI-specific CSS. That split means a component-based renderer is
**additive**, not a rewrite: a `TableComponent` would consume the exact same
`Table`/`Presenter` objects this engine's partials already build, sitting
beside the ERB path rather than replacing internals the decision layer
depends on.
