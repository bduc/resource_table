import { test } from "node:test"
import assert from "node:assert/strict"
import { layoutPayload, layoutWriteSucceeded, sendLayout } from "../../app/javascript/resource_table/layout_command.js"

// sendLayout reads document.querySelector for the CSRF meta tag and calls
// the global fetch — neither exists in plain node, so each test below stubs
// both on globalThis and restores them in a finally, exactly as instructed:
// a stub left behind would leak between tests and hide exactly the kind of
// regression this file exists to catch (dropped CSRF header, wrong verb,
// missing credentials — every one of those still leaves layoutWriteSucceeded
// 8/8 green, which is why sendLayout itself needs direct coverage).
function stubDocument(token = "the-csrf-token") {
  const original = globalThis.document
  globalThis.document = {
    querySelector(selector) {
      assert.equal(selector, "meta[name='csrf-token']")
      return token === null ? null : { content: token }
    }
  }
  return () => {
    if (original === undefined) delete globalThis.document
    else globalThis.document = original
  }
}

function stubFetch(response) {
  const original = globalThis.fetch
  const calls = []
  globalThis.fetch = async (url, options) => {
    calls.push({ url, options })
    return response
  }
  return { calls, restore: () => { globalThis.fetch = original } }
}

test("sendLayout PATCHes the url with credentials, the CSRF header and the layoutPayload body", async () => {
  const restoreDocument = stubDocument("the-csrf-token")
  const { calls, restore: restoreFetch } = stubFetch({ ok: true, redirected: false })

  try {
    const body = { command: "set_column_widths", widths: { title: 180 } }
    const succeeded = await sendLayout("/table_layouts", "BookResource/index", body)

    assert.ok(succeeded)
    assert.equal(calls.length, 1)
    const { url, options } = calls[0]

    assert.equal(url, "/table_layouts")
    assert.equal(options.method, "PATCH")
    assert.equal(options.credentials, "same-origin")
    assert.equal(options.headers["X-CSRF-Token"], "the-csrf-token")
    assert.deepEqual(
      JSON.parse(options.body),
      layoutPayload("BookResource/index", body)
    )
  } finally {
    restoreFetch()
    restoreDocument()
  }
})

test("sendLayout treats a redirected response as a failure, per layoutWriteSucceeded", async () => {
  const restoreDocument = stubDocument("the-csrf-token")
  const { calls, restore: restoreFetch } = stubFetch({ ok: true, redirected: true })

  try {
    const succeeded = await sendLayout("/table_layouts", "BookResource/index", {
      command: "set_column_layout",
      visible: [ "title" ]
    })

    assert.equal(calls.length, 1, "sendLayout must still make the request")
    assert.equal(succeeded, false)
  } finally {
    restoreFetch()
    restoreDocument()
  }
})

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
