# Claude Code Instructions — person_scan

## This repo runs in production
This app runs in `RAILS_ENV=production` locally on port 3010 — there is no
separate dev server. Every change you make is a prod change. Treat it
accordingly: ship it end-to-end as part of your work.

See `CLAUDE.local.md` for environment-specific details (server location,
how to read logs, DB connection).

## Workflow for every change

After making any code change, follow this loop:

1. **Update `CHANGELOG.md`** — add an entry under today's date (UTC+02) with the
   appropriate category: `Features`, `Fixes`, `Security`, `Refactoring`,
   `Design`, `Infrastructure`, `Performance`. If today's date section doesn't
   exist, create it at the top.

2. **Commit and push** — stage the files you touched (named, not `git add -A`),
   commit, push to `origin main`. Default to `[skip ci]` in the commit message
   unless the user explicitly asks for CI to run.

3. **Backfill the commit hash** — run `git rev-parse --short HEAD`, append
   `(abc1234)` to the changelog entry, amend the commit, and push again. This
   lets every changelog line be traced back to its commit.

4. **Compile + restart** — run:
   ```
   RAILS_ENV=production bin/rails assets:precompile
   touch tmp/restart.txt
   ```
   The first rebuilds the asset manifest; the second tells puma to reload
   (configured via `plugin :tmp_restart` in `config/puma.rb`).

   In the user's interactive shell these are aliased to `compile` and
   `restart`, but Bash aliases don't expand in non-interactive tool calls —
   always invoke the full commands above.

5. **Verify it's live** — `curl -s http://localhost:3010/...` and grep for the
   change before reporting done.

## Stack
- Ruby 3.3, Rails 8 (Hotwire, Turbo, Stimulus, Importmap)
- PostgreSQL (production DB: `person_scan_production`)
- Solid Queue (in-Puma), Solid Cache
- Tailwind via `tailwindcss-rails`
- LLM providers: Nebius (default), OpenAI, Anthropic — see `app/services/llm/`

## Frontend
Use Stimulus controllers and Turbo Frames/Streams for interactivity. No
inline JS, no jQuery, no vanilla Ajax.

## Conventions
- Asset path: `app/assets/builds/tailwind.css` is the compiled output; source
  is `app/assets/tailwind/application.css`.
- Public API lives under `Api::V1::*`, authed via `Authorization: Bearer ps_…`
  (`ApiKey` model). Adding endpoints: extend `app/controllers/api/v1/` and
  the `namespace :api do namespace :v1` block in `config/routes.rb`.
- Tracker is `public/t.js` (vanilla JS, served as-is to customer sites).
