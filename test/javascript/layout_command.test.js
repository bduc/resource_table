import { test } from "node:test"
import assert from "node:assert/strict"
import { layoutPayload, layoutWriteSucceeded } from "../../app/javascript/resource_table/layout_command.js"

test("a width command carries the key and the widths", () => {
  assert.deepEqual(
    layoutPayload("BookResource/index", { command: "set_column_widths", widths: { title: 180 } }),
    { key: "BookResource/index", widths: { title: 180 } }
  )
})

test("a layout command carries the key and the visible list", () => {
  assert.deepEqual(
    layoutPayload("BookResource/index", { command: "set_column_layout", visible: ["title", "pages"] }),
    { key: "BookResource/index", visible: ["title", "pages"] }
  )
})

test("the command name itself is not sent — the endpoint infers it from the keys", () => {
  const payload = layoutPayload("K", { command: "set_column_widths", widths: {} })
  assert.equal(payload.command, undefined)
})

test("an unknown command yields null rather than posting something arbitrary", () => {
  assert.equal(layoutPayload("K", { command: "drop_table", widths: {} }), null)
})

test("a missing key yields null", () => {
  assert.equal(layoutPayload("", { command: "set_column_widths", widths: {} }), null)
})

// A layout PATCH should never be redirected. A must_reset_password gate (or
// anything else that intercepts the request) sends the browser to an HTML
// page instead; fetch follows that transparently and reports `ok: true` for
// the page it landed on, not for the write, which never happened.

test("a 2xx, non-redirected response counts as a successful write", () => {
  assert.ok(layoutWriteSucceeded({ ok: true, redirected: false }))
})

test("a redirected response counts as a failure even though fetch reports ok", () => {
  assert.ok(!layoutWriteSucceeded({ ok: true, redirected: true }))
})

test("a non-2xx, non-redirected response counts as a failure", () => {
  assert.ok(!layoutWriteSucceeded({ ok: false, redirected: false }))
})
