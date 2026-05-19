# Changelog

## 2026-05-19

### Features
- Familiarity normalization for personality classification. Returning
  visitors who know the site behave decisively for a different reason
  than first-timers who are decisive by personality — same raw signal,
  different meaning. Two-step rollout:
    1. `FeatureAggregator` exposes a new `familiarity` block:
       `is_returning`, `visitor_age_seconds`/`_days`, `distinct_active_days`,
       `total_page_visits`, `distinct_urls_visited`, `visits_to_current_url`,
       and `time_to_first_move_ms` (per-pageload + summary). All derived
       from existing data plus the new tracker signal.
    2. Tracker (`public/t.js`) has a new `FirstMoveTracker`: from
       `DOMContentLoaded` until the first mouse motion with >20px
       displacement in <500ms (filters out cursor pass-throughs). Sent
       once per page load on the first track batch.
    3. Migration adds `time_to_first_move_ms:integer` to `tracking_events`.
    4. Prompt template extended with explicit interpretation rules:
       discount decisiveness/impulsivity when `is_returning` is true or
       `visits_to_current_url > 1` or `time_to_first_move_ms` is very
       short; <800ms = goal-directed, 800-2500ms = orienting, >2500ms =
       slow orientation.
  Verified live by re-classifying visitor c54d63d474b9 — label flipped
  from "Cautious Browser" to "Familiar Returner" with rationale
  explicitly noting familiarity discount. Tracker round-trip verified:
  POST /visitor/track with time_to_first_move_ms=420 persisted on
  TrackingEvent. (af21162)

- `SweepStalePredictionsJob` — recurring smart-sweep that re-classifies
  visitors only when they have meaningful new data. Runs every 15 minutes
  via `config/recurring.yml`. Filter: `last_seen_at` within the last 7
  days (recently active), quiet for at least 2 minutes (no mid-session
  classification), and at least 3 new tracking-/click-/page-events since
  the latest prediction (or 3+ total events for first-time predictions).
  Hard-capped at 200 enqueues per run. Enqueues into the existing
  `ClassifyVisitorJob`, whose 30s debounce de-dups with ingest-driven
  classifications. First dry-run on 4 prod visitors: enqueued=0,
  skipped_session=1, skipped_thin=3 — logic confirmed. (8292593)

### Infrastructure
- Add Nebius API key to encrypted Rails credentials
  (`Rails.application.credentials.dig(:nebius, :api_key)`). Without it,
  `ClassifyVisitorJob` was raising `Llm::ConfigError` on every dispatch and
  the `discard_on` swallowed it silently — every visitor's `latest_prediction`
  came out `nil` regardless of how many tracking events they had. Verified
  by running `PersonalityClassifier.call` on visitor c54d63d474b9 (37
  events) and getting back a real `Prediction` with label / dimensions /
  confidence. (c2e7243)

### Design
- Replace inline flash banners with a fixed top-right toast in all three
  layouts (`application`, `auth`, `landing`). Stimulus `flash_controller`
  slides the card in, auto-dismisses after 4.5s (7s for alerts), and a close
  button is always available. Colored left bar + icon distinguishes notice
  (emerald) from alert (red). White card with shadow reads on both the
  light app background and the dark auth/landing gradient. (b509a70)

### Fixes
- Close signup loophole — `UsersController#create` previously fell back to
  the `free` plan when no `plan` param was supplied, letting anyone POST
  `/users` and bypass plan selection. Now requires a valid plan in `PLANS`
  and redirects to `/pricing` otherwise. Also applies the `auth` layout to
  the create action so re-rendered validation errors stay on the dark theme,
  and the rate-limit redirect targets `/pricing` (signup needs a plan param). (b509a70)

### Features
- Gate signup behind plan selection — all splash / landing CTAs route to
  `/pricing`. `/signup` now requires a `?plan=` param (else redirects to
  `/pricing` with a notice). Free signups create the user directly; paid
  signups create the user, sign them in, and redirect into Stripe Checkout
  with a 14-day trial. Unauthenticated visits to `/stripe/checkout?plan=X`
  now redirect to `/signup?plan=X` (instead of `/login`), so the user can
  register on the way. (0211498)

### Design
- Add "Pricing" link to the authenticated main nav in `application.html.erb`
  (landing nav already had it). (d1646e8)
- Redesign auth layout (signup / login / password reset) with the same
  dark `stone-950 → stone-900` gradient as `/pricing`. Single-column with
  the logo at the top, amber-500 submit buttons, white-on-dark form fields.
  Signup view shows a "Selected plan" banner with a Change link back to
  `/pricing`. (0211498)
- Fix logo on landing header against dark backgrounds — apply
  `brightness-0 invert` so the dark-text logo renders white on the pricing
  hero and the auth layout (where it was previously invisible). (0211498)

## 2026-05-18

### Features
- Create Stripe Products + monthly Prices via API (test mode, EUR) and
  inject the resulting price IDs into credentials. Products use
  `lookup_key` (`person_scan_{starter,growth,scale}_monthly_eur`) so re-runs
  are idempotent. Stripe Checkout is now end-to-end functional in test mode;
  only `stripe.test.webhook_secret` remains a placeholder until the public
  webhook endpoint is registered in the Stripe Dashboard. (3075a84)

### Features
- Wire Stripe Checkout for paid plans — adds `stripe ~> 13.0` gem, `StripeConfig`
  helper that reads keys per mode (test/live) from credentials, `StripeCheckoutController`
  (new/success/cancel) that creates a Stripe Customer on first checkout and
  starts a 14-day trial subscription, and `StripeWebhooksController` for
  `customer.subscription.created/updated/deleted`. New routes under `/stripe/*`.
  Pricing-page CTAs (Starter/Growth/Scale) now route to Stripe Checkout.
- Add `users.stripe_customer_id`, `users.plan` (default `free`),
  `users.trial_ends_at`, and `subscriptions` table with `stripe_subscription_id`
  unique. `User` model gains `PLANS`, `has_many :subscriptions`,
  `active_subscription`, `on_paid_plan?`. (ebdfc15)
- Copy Stripe API keys from the reemove app's credentials into person_scan's
  `stripe.{test,live}.{secret_key,publishable_key}` (same Stripe account).
  Webhook secrets and price IDs are placeholders pending creation of
  person_scan-specific products + a registered webhook endpoint in the
  Stripe Dashboard. (ebdfc15)

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
