import { test } from "node:test"
import assert from "node:assert/strict"
import { layoutPayload } from "../../app/javascript/resource_table/layout_command.js"

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
