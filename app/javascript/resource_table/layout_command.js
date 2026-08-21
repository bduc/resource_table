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
    if (!response.ok) console.warn("table layout rejected", response.status)
    return response.ok
  } catch (error) {
    console.warn("table layout failed", error)
    return false
  }
}
