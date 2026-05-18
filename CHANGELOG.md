# Changelog

## 2026-05-18

### Design
- Sharpen splash messaging — hero from "Know what your visitors are like" to
  "Drop one line on your site. Get the profile of every visitor." Subhead
  reframed around personality/intent/conversion. "Know your users" listicle
  rewritten as outcomes (who/what/how-close + dashboard+API). "How it works"
  steps rewritten in active voice with a stronger close on step 3. (1fe7161)
- Replace remaining `Person Scan` brand string with `individlabs` in
  `sessions/new.html.erb`. (1fe7161)
- Switch primary button accent from amber to stone in `tailwind/application.css`
  (`.btn`, `.btn-primary` hover/border updated). (1fe7161)

### Refactoring
- Extract `Llm::Error`, `Llm::ConfigError`, `Llm::ApiError` from
  `app/services/llm/provider.rb` into their own files. (1fe7161)

### Infrastructure
- Add Claude Code workflow rules — `CLAUDE.md` and `CLAUDE.local.md` describing
  the prod workflow (changelog + commit + push + compile + restart on every
  change), modeled on the reemove sibling app's setup. Seed `CHANGELOG.md` and
  add `.claude/settings.local.json` with permits for the workflow commands.
  `CLAUDE.local.md` and `.claude/settings.local.json` are gitignored. (1fe7161)

### Design
- Shrink logo by 20% across all three layouts — `h-16` → `h-[3.2rem]` in
  `auth.html.erb` and `landing.html.erb`, `h-14` → `h-[2.8rem]` in
  `application.html.erb`. (1fe7161)

### Features
- Add pricing page at `/pricing` — Free + Starter (€29 / 1k profiles) +
  Growth (€99 / 10k, "Most popular") + Scale (€299 / 50k + API + webhooks).
  Billable unit is a "profile" = a Prediction with confidence ≥ 0.7, so
  uncertain reads and bots don't bill. Adds nav link in landing layout.
  CTAs route to `signup?plan=...` for now — Stripe Checkout wiring is the
  next step. (1fe7161)
