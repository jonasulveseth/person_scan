import { Controller } from "@hotwired/stimulus"

// Auto-dismissing flash toast. Usage:
//   <div data-controller="flash" data-flash-delay-value="5000"> ... </div>
export default class extends Controller {
  static values = { delay: { type: Number, default: 5000 } }

  connect() {
    // Slide in
    requestAnimationFrame(() => {
      this.element.classList.remove("opacity-0", "translate-x-4")
      this.element.classList.add("opacity-100", "translate-x-0")
    })
    if (this.delayValue > 0) {
      this.timeout = setTimeout(() => this.dismiss(), this.delayValue)
    }
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.classList.remove("opacity-100", "translate-x-0")
    this.element.classList.add("opacity-0", "translate-x-4")
    setTimeout(() => this.element.remove(), 200)
  }
}
