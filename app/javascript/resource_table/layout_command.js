// The command payload, extracted from the controller so it is node-testable
// without a DOM — the same reason viewport_ownership.js exists in mira.
//
// The endpoint takes a key plus whichever of `visible`/`widths` changed; the
// mep-era `command` discriminator does not cross over, because the two commands
// touch disjoint keys and the server can tell them apart without being told.
const COMMANDS = {
  set_column_widths: "widths",
  set_column_layout: "visible"
}

export function layoutPayload(key, body) {
  if (!key) return null
  const field = COMMANDS[body && body.command]
  if (!field) return null

  return { key, [field]: body[field] }
}

// Whether a fetch Response represents an actual layout write. A layout PATCH
// should never be redirected — if it is (e.g. mira's must_reset_password
// gate sends a signed-in user to an HTML page instead of handling the PATCH),
// fetch transparently follows the redirect and reports `ok: true` for the
// *redirect target*, not for the write. Split out, like layoutPayload, so
// node --test can exercise the decision without a fetch mock.
export function layoutWriteSucceeded(response) {
  return response.ok && !response.redirected
}

export async function sendLayout(url, key, body) {
  const payload = layoutPayload(key, body)
  if (!payload) return false

  const token = document.querySelector("meta[name='csrf-token']")?.content || ""
  try {
    const response = await fetch(url, {
      method: "PATCH",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": token
      },
      body: JSON.stringify(payload)
    })
    const success = layoutWriteSucceeded(response)
    if (!success) console.warn("table layout rejected", response.status)
    return success
  } catch (error) {
    console.warn("table layout failed", error)
    return false
  }
}
