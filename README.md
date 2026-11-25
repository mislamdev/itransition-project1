# Stockroom — Inventory Management

A production-oriented Rails application for creating reusable inventories, defining custom fields, and cataloguing items with inventory-specific custom IDs.

The interface is table-first and responsive: inventories, items, search results, access lists, custom fields, statistics, personal workspaces, and administration are all represented as semantic tables rather than card galleries.

## Implemented features

- **Arbitrary inventories** with categories, Markdown descriptions, tags, cloud-image URLs, visibility, and owner-defined settings.
- **Custom fields** with single-line text, multi-line text, numeric, document-link, boolean, and select types. The core limits of three fields per type are enforced in the model.
- **Custom inventory IDs** built from fixed Unicode text, 20/32-bit random numbers, 6/9-digit random numbers, GUIDs, timestamps, and locked sequence counters.
  - The same renderer generates, validates, and previews IDs.
  - Uniqueness is enforced by the database index `(inventory_id, custom_id)`.
  - Existing IDs are not rewritten when a format changes.
- **Authorization** with guest read-only access, authenticated collaborators, inventory owners, and administrator owner-equivalent access.
- **Access management** with public/private inventories, user autocomplete by name or email, and name/email sorting.
- **Optimistic locking** on inventories and items, including friendly `409 Conflict` responses for stale autosaves.
- **Debounced inventory autosave** every eight seconds, with version chaining and a reloadable conflict panel.
- **Full-text search** using PostgreSQL `tsvector` columns and GIN indexes, with a portable SQLite fallback.
- **Linear discussions** with sanitized CommonMarker Markdown, Turbo Stream support, and four-second polling fallback.
- **Likes**, a tag cloud, inventory statistics, personal owned/shared tables, and administrator user management (including self-demotion).
- **English and Spanish UI**, plus persistent light and dark themes.
- **Local email/password authentication** and environment-driven Google and Facebook OmniAuth providers.

## Stack

- Ruby 4.0.5 / Rails 8.1
- PostgreSQL 16 (SQLite fallback supported by `DB_ADAPTER=sqlite3`)
- ActiveRecord, Minitest
- Propshaft, local Bootstrap 5.3.3, Turbo, Stimulus, Action Cable
- CommonMarker for sanitized Markdown
- OmniAuth for Google and Facebook

## Requirements

- Ruby 4.0.5 (the version in `.ruby-version`)
- Bundler 4
- PostgreSQL 16, or SQLite for the portable fallback
- A JavaScript runtime is optional; the application uses import maps and has no Node build step

## Local setup

The sandbox-friendly setup keeps gems inside the workspace:

```bash
source script/env.sh
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails server -b 127.0.0.1 -p 3123
```

Open <http://127.0.0.1:3123>.

On a normal workstation, `source script/env.sh` is unnecessary; use `bundle install`, `bin/rails db:prepare`, and `bin/rails server` directly.

### Demo accounts

`bin/rails db:seed` creates:

| Role | Email | Password |
|---|---|---|
| Administrator | `admin@example.com` | `administrator` |
| Regular user | `demo@example.com` | `demopassword` |

Change or remove these credentials before deploying publicly.

## Configuration

Copy `.env.example` to `.env` and set only the values you need. The file is
read in the development environment (the `dotenv-rails` gem); in production
the variables come from the environment of the server. The most important
production settings are:

```bash
DATABASE_URL=postgres://user:password@host/inventory_management_production?seeds=false
SECRET_KEY_BASE=...
RAILS_MASTER_KEY=...
```

`?seeds=false` keeps `db/seeds.rb` out of a fresh database — the demo
accounts of the seeds file have public passwords.

`config/master.key` is intentionally ignored by Git. Supply `RAILS_MASTER_KEY` or `SECRET_KEY_BASE` in production.

Behind a TLS terminating proxy (Nginx, Cloud 66, a load balancer) the application
needs two more variables, otherwise it treats the proxied request as plain HTTP:

```bash
ASSUME_SSL=true   # the proxy forwards X-Forwarded-Proto: https
FORCE_SSL=true    # secure cookies and Strict-Transport-Security
APP_HOST=stockroom.example.com          # used for generated links
APP_HOSTS=stockroom.example.com         # optional: accepted Host headers
```

### Google and Facebook sign-in

Providers are enabled only when their credentials exist:

```bash
GOOGLE_OAUTH_CLIENT_ID=...
GOOGLE_OAUTH_CLIENT_SECRET=...
FACEBOOK_APP_ID=...
FACEBOOK_APP_SECRET=...
```

Configure these callback URLs with the providers:

- Google: `http://localhost:3123/auth/google_oauth2/callback`
- Facebook: `http://localhost:3123/auth/facebook/callback`

Use the public HTTPS application URL instead of `localhost` in production.

## Verification

Run the complete suite serially in this environment:

```bash
source script/env.sh
PARALLEL_WORKERS=1 bin/rails test
```

Expected result:

```text
167 runs, 504 assertions, 0 failures, 0 errors, 0 skips
```

Additional checks:

```bash
bin/rubocop --format simple
bundle exec brakeman --no-pager --no-exit-on-warn
bin/rails runner script/smoke_test.rb
```

`bin/brakeman` performs an online freshness check; `bundle exec brakeman` runs the local scanner without requiring that network request.

The domain smoke script creates a temporary inventory, generates IDs, checks the composite uniqueness constraint, validates typed values, and exercises search/statistics.

## Architecture notes

### Data model

- `User` — accounts, roles, blocking, session invalidation, locale, and theme.
- `Inventory` — owner, settings, public visibility, `lock_version`, and `items_count` counter cache.
- `Item` — custom ID, typed field values, `lock_version`, and search text.
- `Field` / `FieldValue` — stable field definitions and typed values.
- `InventoryAccess` — explicit write collaborators.
- `IdFormatElement` / `InventorySequence` — custom-ID format and concurrency-safe counters.
- `Comment`, `Like`, `Tag` — discussion, one-like-per-user, and global tag namespace.

### Custom-ID rules

`CustomId::Formatter` is the single source of truth for generation, server-side validation, and the live preview. A database unique index is the final concurrency guard, so a duplicate random/sequence result is rejected and shown to the user rather than silently overwriting an item.

### Search

PostgreSQL stores generated `tsvector` columns for inventories and items with GIN indexes. Search terms are prefix queries; item text is normalized into word tokens so a custom ID such as `OFF-0001` is discoverable by `0001`.

### UI architecture

The frontend uses semantic HTML tables, Bootstrap 5, and a small custom CSS token theme. Table actions live in selection toolbars above tables; item rows link to item pages rather than containing permanent action-button clusters. Drag-and-drop features have keyboard move controls, and the layout includes a skip link, visible focus states, reduced-motion support, and responsive table containers.

## Container deployment

Build and run the production image:

```bash
docker build -t stockroom .
docker run --rm -p 3000:3000 \
  -e DATABASE_URL="$DATABASE_URL" \
  -e SECRET_KEY_BASE="$SECRET_KEY_BASE" \
  stockroom
```

The entrypoint runs `db:prepare` before starting Puma: it waits for the
database to accept connections, creates the schema from `db/structure.sql`
when it is missing and runs the pending migrations afterwards. Supply
`RAILS_MASTER_KEY` instead of `SECRET_KEY_BASE` when encrypted credentials are
required.

Append `?seeds=false` to the database URL to keep the demo accounts of
`db/seeds.rb` out of a fresh database:

```bash
DATABASE_URL="postgres://user:password@host/database?seeds=false"
```

## Deployment on Cloud 66

[`docs/deployment/cloud66.md`](docs/deployment/cloud66.md) is the complete
guide for deploying Stockroom to [Cloud 66](https://www.cloud66.com):

- **Cloud 66 Deploy** (recommended): the application is built from the
  `Dockerfile` and runs on a managed Kubernetes cluster.
- **Cloud 66 for Rails**: the application is installed on a virtual machine
  and served with Puma.

The configuration that belongs to Cloud 66 lives in the repository:

| File | Purpose |
|---|---|
| `config/cloud66/service.yml` | Service definition of the container (ports, health probes, database) |
| `config/cloud66/env.vars.example` | Template for the environment variables of the application |
| `.cloud66/manifest.yml` | Pinned Ruby and PostgreSQL versions, health check, ActiveProtect settings |
| `.cloud66/deploy_hooks.yml` | Migration hook of the virtual machine path |
| `Procfile` | Puma web process of the virtual machine path |

## Deployment on DOM Cloud

[`docs/deployment/domcloud.md`](docs/deployment/domcloud.md) describes the
deployment on [DOM Cloud](https://domcloud.co), where the application runs on
a shared Rocky Linux server with NGINX and Passenger. The whole deployment is
one YAML script:

[`config/domcloud/deploy.yml`](config/domcloud/deploy.yml)

It clones the repository, installs Ruby 4.0.5 with RVM, creates the managed
PostgreSQL database, installs the gems, prepares the schema, compiles the
assets and serves the application with Puma.

## Localization

The generated locale files are committed so the interface is deployable immediately:

- `config/locales/en.yml`
- `config/locales/es.yml`

Edit `script/translations_es.yml` and the view defaults, then regenerate:

```bash
bin/rails runner script/build_locales.rb
```

The command reports any missing Spanish keys.

## Current deliberate limitations

- Inventory illustrations are stored as cloud-hosted URLs; files are never uploaded to the application server or database.
- OAuth requires provider credentials; local email/password authentication remains available without them.
- CSV/Excel export, inline document previews, and email confirmation are optional enhancements and are not included in this build.

## Further reading

- `inventory-management-requirements.md` — original project requirements
- `db/structure.sql` — PostgreSQL schema, indexes, and full-text search columns
- `app/services/custom_id/` — custom-ID generation and validation
- `app/services/search.rb` — full-text search adapter
- `script/smoke_test.rb` — executable domain walkthrough
