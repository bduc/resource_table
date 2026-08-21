import { Controller } from "@hotwired/stimulus"
import { sendLayout } from "./layout_command.js"

// The column picker. A change posts the same PATCH the drag gestures use, then
// reloads so the server re-renders the table with the new column set.
export default class extends Controller {
    static values = { url: String, key: String }

    async toggle() {
        const visible = Array.from(this.element.querySelectorAll("input[type=checkbox]"))
            .filter(input => input.checked)
            .map(input => input.value)

        if (await sendLayout(this.urlValue, this.keyValue, { command: "set_column_layout", visible })) {
            window.location.reload()
        }
    }
}
