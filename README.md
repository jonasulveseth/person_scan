# Person Scan

Behavioral-analytics SaaS: customers install a tracking `<script>` on their site, visitors get
classified into sales-oriented personality profiles via LLM, and customers consume the data
through a dashboard or REST API.

This is a modern Rails 8 rewrite of an older (Rails 4.2) prototype. The vanilla-JS tracker
(`public/t.js`) is ported from `lib/assets/external-js/analyzer.js` in the legacy app and
keeps the original feature set — mouse motion curvature distributions, decisive-vs-indecisive
scroll groups, click times, link hover-to-click overtime, page enter/leave with last-click,
mobile orientation.

## Stack

- Ruby 3.3, Rails 8 (Hotwire, Turbo, Stimulus, Importmap)
- PostgreSQL (with `jsonb` features columns)
- Solid Queue (in-process jobs), Solid Cache
- Tailwind CSS via `tailwindcss-rails`
- LLM providers (pluggable): **Nebius** (default), OpenAI, Anthropic

## Local setup

```bash
# Prereqs: ruby 3.3, postgres, node (for tailwindcss-rails standalone build)
git clone <repo> person_scan
cd person_scan
bundle install
bin/rails db:create db:migrate db:seed
```

Add at least one LLM provider API key to encrypted credentials:

```bash
bin/rails credentials:edit
```

```yaml
# config/credentials.yml.enc (decrypted)
nebius:
  api_key: nebius_xxxxxxxxxxxxxxxxxx
# Optional:
openai:
  api_key: sk-...
anthropic:
  api_key: sk-ant-...
```

Run the dev server (Tailwind compiles on the fly via `bin/dev`):

```bash
bin/dev
```

Browse `http://localhost:3000` and sign up.

## End-to-end flow

1. **Sign up** → creates a User and lands you on `/sites`.
2. **Create a site** → generates a `public_key` shown in the install snippet.
3. **Install snippet** on your test site (or use the bundled `public/test.html` from the legacy app):
   ```html
   <script src="https://your-host/t.js?site=PUBLIC_KEY"></script>
   ```
4. **Visit your site** and interact → events flow in. `ClassifyVisitorJob` aggregates features
   and asks the active LLM for a personality profile.
5. **Watch predictions** appear on `/sites/:id`. Drill into a visitor for full feature dump,
   reclassification with another model, and one-click "save as training example".

## Architecture

```
tracker (public/t.js) -- POST --> ingest controllers --> raw event tables (Postgres)
                                                            |
                                          ClassifyVisitorJob (Solid Queue, debounced 30s)
                                                            |
                            FeatureAggregator --> VisitorFeature
                                                            |
                            Llm::Provider.for(ModelConfig) --> Prediction
                                                            |
                         Dashboard /sites/:id/visitors/:id ---|
                                                            |
                         Public API /api/v1/visitors/:fp -----+
```

### Key files

- `public/t.js` — tracker (vanilla JS, no deps; runs on customer sites)
- `app/controllers/ingest/` — 4 endpoints: new-session, track, link_clicks, page_visits
- `app/services/feature_aggregator.rb` — raw events → per-visitor features hash
- `app/services/llm/{provider,nebius,open_ai,anthropic,open_ai_compatible}.rb` — LLM adapters
- `app/services/personality_classifier.rb` — orchestration
- `app/services/legacy_importer.rb`, `legacy_csv_importer.rb` — training-data import
- `app/services/evaluation_runner.rb` — accuracy evaluation against `TrainingExample`s
- `app/services/site_trends.rb` — per-site aggregate stats

## Models (LLM adapters)

| Provider key | Class             | Credentials key             |
|--------------|-------------------|-----------------------------|
| `nebius`     | `Llm::Nebius`     | `nebius.api_key`            |
| `openai`     | `Llm::OpenAi`     | `openai.api_key`            |
| `anthropic`  | `Llm::Anthropic`  | `anthropic.api_key`         |

Adding a provider:
1. Create `app/services/llm/<name>.rb` (inherit `OpenAiCompatible` if OpenAI-style)
2. Add to `Llm::Provider::REGISTRY` and `ModelConfig` provider validation
3. Add a credentials key

Configure models at `/model_configs`; each Site can override its model at `/sites/:id/edit`.

## Training data + evaluation

- **Import legacy SQLite** (limited): `/training_examples` → "Import SQLite"
- **Import legacy CSV** (`public/csv/gender.csv` from old app, 1287 labeled rows): "Import CSV"
- **Manual examples**: "Add manually" or from any visitor page → "Save as training example"
- **Run an eval**: `/evaluation_runs` → pick a model, sample size; see per-example breakdown
  with gender/age-bracket accuracy

## Public API v1

All endpoints require `Authorization: Bearer <api_key>` (manage keys at `/sites/:id/api_keys`).

| Method | Path                              | Description                              |
|--------|-----------------------------------|------------------------------------------|
| GET    | `/api/v1/site`                    | Site metadata + active model + trends    |
| GET    | `/api/v1/visitors?page=&per_page=`| Paginated list w/ latest prediction      |
| GET    | `/api/v1/visitors/:fingerprint`   | Visitor detail + features + prediction   |

Example:

```bash
TOKEN=ps_xxxxxxxxxxxxxxxxxx
curl -H "Authorization: Bearer $TOKEN" https://your-host/api/v1/visitors | jq .
```

## Deployment

Rails 8 ships with Kamal config (`config/deploy.yml`) and a production-ready `Dockerfile`.

Quick path to deploy on a single VPS:

```bash
# 1. Edit config/deploy.yml with your server, registry, domain
# 2. Set KAMAL_REGISTRY_PASSWORD and RAILS_MASTER_KEY in .kamal/secrets
kamal setup        # first time only
kamal deploy
```

Required production env vars / secrets:
- `RAILS_MASTER_KEY` — for decrypting credentials
- `DATABASE_URL` — or use the YAML config
- `SOLID_QUEUE_IN_PUMA=1` — to run the job worker in the web process (default in dev)

For higher throughput, run Solid Queue as a separate process:

```bash
bin/jobs                       # in production: a dedicated `bin/jobs` container
```

## Open work

- Improve prompt quality: add few-shot examples drawn from `TrainingExample`s with high
  confidence; current default already enforces enum + age-bracket whitelist
- Charts in the trends view (current is ASCII bars + tables)
- Real auth roles: admin vs. customer (today every signed-in user can edit all ModelConfigs)
- Cron / archive job for old raw events (Solid Queue has `config/recurring.yml`)
- More providers: Google Gemini, local Ollama
