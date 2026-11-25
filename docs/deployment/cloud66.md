# Deploying Stockroom on Cloud 66

This guide takes the **Stockroom** Rails application from the repository
(<https://github.com/mislamdev/itransition-project1.git>) to a running
production environment on [Cloud 66](https://www.cloud66.com).

It covers both Cloud 66 products, but only one of them is recommended:

| Cloud 66 product | What it does | Fit for Stockroom |
|---|---|---|
| **Cloud 66 Deploy** (recommended) | Builds the app into a container, runs it on a managed Kubernetes cluster | The repository already ships a production `Dockerfile`, and Ruby 4.0.5 is newer than the Ruby catalogue of the virtual machine product. The image pins the exact Ruby version, so nothing depends on what Cloud 66 has installed on a server. |
| **Cloud 66 for Rails** | Installs Ruby, Nginx and Passenger/Unicorn on a virtual machine and deploys the code with git | Works, but the Ruby version has to be one that Cloud 66 supports on its Ubuntu images. Use it only if you cannot use containers. |

---

## 1. Prerequisites

- A **Cloud 66 account** (the first server is free, no credit card needed).
- A **cloud provider account** — AWS, DigitalOcean, Google Compute Engine,
  Hetzner, Latitude.sh, Linode, OVHcloud, Azure or Vultr.
- The repository pushed to a git host that Cloud 66 can read. This guide uses
  GitHub, which is already set up:
  `https://github.com/mislamdev/itransition-project1.git` (branch `main`).
- A **domain name** with DNS you control, for the public URL and the SSL
  certificate (optional for a first smoke test, required for production).
- The **Toolbelt** CLI if you prefer the command line over the dashboard:

  ```bash
  curl -L https://app.cloud66.com/get-toolbelt -o /usr/local/bin/cx && chmod +x /usr/local/bin/cx
  cx login
  ```

## 2. What Cloud 66 needs to know about Stockroom

| Item | Value | Where it comes from |
|---|---|---|
| Language | Ruby 4.0.5 | `.ruby-version`, also pinned in the `Dockerfile` |
| Framework | Rails 8.1.4.1 | `Gemfile` / `Gemfile.lock` |
| Database | **PostgreSQL** (16 recommended) | `config/database.yml`, `db/structure.sql` |
| Web server | Puma on port **3000** | `config/puma.rb` |
| Container port | `3000` | `Dockerfile` (`EXPOSE 3000`) |
| Health endpoint | `GET /up` → `200` | `config/routes.rb` |
| Public path | `/` → `200` for guests (the dashboard) | `config/routes.rb` |
| Assets | Propshaft, precompiled **in the image** | `Dockerfile` build stage |
| Schema format | `db/structure.sql` (plain SQL, not `schema.rb`) | `config/application.rb` |
| Background jobs | none required (ActiveJob runs in-process) | `app/jobs` |
| Persistent disk | none — the application stores images as URLs, not files | `README.md` |

Two properties of the application matter for the deployment:

- **PostgreSQL is not optional in production.** The search uses generated
  `tsvector` columns with GIN indexes (`db/migrate/20261115202113_add_search_vectors.rb`).
  The SQLite fallback exists for portable development only.
- **The image is self-contained.** Assets are compiled during the image build,
  so no Node/Yarn toolchain and no asset compilation step is needed on the
  servers.

## 3. Path A — Cloud 66 Deploy (Kubernetes, recommended)

### 3.1 Create the application

1. Sign in to the [Cloud 66 Dashboard](https://app.cloud66.com) and click
   **New Application**.
2. **Step 1 — Choose a source:** pick the *Github app* tab, click
   **Get Started** → **Link with Github**, install the Cloud 66 GitHub app for
   `mislamdev/itransition-project1` (read-only access is enough).
3. **Step 2 — Define the application:** choose the repository, the branch
   `main`, the environment `production`, a name (for example `stockroom`) and
   click **Analyze**. Cloud 66 detects the Dockerfile and suggests a service.
4. **Step 3 — Configure the service.** Use `config/cloud66/service.yml` from
   this repository as the reference; the important values are:

   ```yaml
   services:
     web:
       git_url: https://github.com/mislamdev/itransition-project1.git
       git_branch: main
       dockerfile_path: Dockerfile
       ports:
         - container: 3000
           http: 80
           https: 443
   ```

   Apply it with **Application → ↧ More → Edit service.yml**, paste the
   contents of `config/cloud66/service.yml` and commit the change.
5. **Step 4 — Add a cloud provider:** **Add a Deployment Target**, pick your
   provider, and choose the region and the size of the servers. One worker
   node with 2 vCPU / 4 GB is a good start for a small inventory application.
6. **Step 5 — Deploy:** click **Start Deployment**. The first build compiles
   the gems and the assets and takes a while (10–20 minutes on a small
   instance).

### 3.2 Add PostgreSQL

1. **Data Sources → Add Source → Postgres → Add Server**.
2. Pin the version in the manifest so that a new server is never created with
   a different major version (see `.cloud66/manifest.yml` in this repository):

   ```yaml
   production:
     postgresql:
       configuration:
         version: 16
   ```

3. Cloud 66 provisions the database, creates the credentials and publishes
   them as environment variables. Check **Settings → Environment Variables**
   for `DATABASE_URL` (plus the `POSTGRESQL_*` / `POSTGRES_*` companions).
4. **Use `?seeds=false` in the URL.** Cloud 66 builds the URL for you; append
   the Rails query option so that a brand new database is *not* filled with
   the demo accounts:

   ```
   postgres://<user>:<password>@<host>:5432/<database>?seeds=false
   ```

   `db:prepare` only loads `db/seeds.rb` when it has to create the database,
   and `seeds=false` switches that off. The demo data (including the
   `admin@example.com` / `administrator` account) is then never created.

### 3.3 Environment variables

Add these under **Settings → Environment Variables → Your Custom Variables**.
They are only applied on the next deployment.

| Variable | Value | Why |
|---|---|---|
| `RAILS_ENV` | `production` | Set by Cloud 66 for the production environment. |
| `SECRET_KEY_BASE` | a fixed random value (`openssl rand -hex 64`) | It signs the session cookies, so it has to stay the same over the deployments. The `AUTO_GENERATE_64` placeholder of Cloud 66 is replaced with a **new** value on every deployment, which would log every user out. |
| `DATABASE_URL` | `postgres://...?seeds=false` | The managed database. Prefer the variable Cloud 66 generates; add `?seeds=false`. |
| `ASSUME_SSL` | `true` | Nginx terminates TLS and forwards plain HTTP with `X-Forwarded-Proto: https`. Without this flag Rails believes the request was plain HTTP and builds `http://` URLs. |
| `FORCE_SSL` | `true` | Secure cookies and HSTS. The HTTP → HTTPS redirect itself is done by the Cloud 66 Nginx, because the application only ever sees the internal HTTP request. |
| `RAILS_MAX_THREADS` | `5` | Threads per Puma worker. Keep `RAILS_MAX_THREADS × WEB_CONCURRENCY` below the PostgreSQL connection limit (`max_connections`). |
| `RAILS_LOG_LEVEL` | `info` | `debug` logs every parameter — do not use it in production. |
| `APP_HOST` | `stockroom.example.com` | Used for links in emails and OAuth redirects. |
| `APP_HOSTS` | `stockroom.example.com,www.example.com` | Optional: restricts the accepted `Host` headers. Leave empty to accept every host. |
| `APP_PROTOCOL` | `https` | Protocol for generated URLs. |
| `GOOGLE_OAUTH_CLIENT_ID` / `GOOGLE_OAUTH_CLIENT_SECRET` | optional | Google sign-in. The callback URL is `https://<domain>/auth/google_oauth2/callback`. |
| `FACEBOOK_APP_ID` / `FACEBOOK_APP_SECRET` | optional | Facebook sign-in. The callback URL is `https://<domain>/auth/facebook/callback`. |

`config/cloud66/env.vars.example` in this repository contains the same list in
the `KEY=value` format that the dashboard and `cx env-vars upload` accept.

### 3.4 What happens to the database

The image entry point (`bin/docker-entrypoint`) runs `bin/rails db:prepare`
before Puma starts. `db:prepare`:

1. creates the database if it does not exist yet,
2. loads `db/structure.sql` when the schema is missing (this includes the
   `tsvector` columns and the GIN indexes),
3. runs the pending migrations otherwise.

Because `DATABASE_URL` carries `?seeds=false`, the demo data is **not** loaded
on a fresh database. To create the demo data on purpose (for a staging
environment):

```bash
cx run --stack stockroom --command "bin/rails db:seed"
```

The entry point also waits for the database to accept connections
(`pg_isready`, 30 attempts of 2 seconds) before it touches the schema, so the
container survives being started at the same moment as the database.

If you prefer to run the migrations from Cloud 66 instead of from the
container, set `deploy_command` in `service.yml` to `bin/rails db:prepare`
and add `SKIP_DB_PREPARE_ON_BOOT=true` to the environment variables — the
entry point then leaves the schema alone.

### 3.5 SSL certificate and DNS

1. Point the domain at the Cloud 66 load balancer (an `A`/`AAAA` record, or a
   `CNAME` to the address shown in **Application → DNS**).
2. **Application → SSL Certificate → Add SSL Certificate → Standard**. Enter
   the domain and the subdomains. Let's Encrypt needs to reach
   `http://<domain>/.well-known/acme_challenge/*` over plain HTTP, so port 80
   must stay open.
3. Keep the **SSL termination** option enabled: the Nginx of Cloud 66
   terminates TLS and talks plain HTTP to the pods, which is exactly what
   `ASSUME_SSL=true` expects.
4. Certificates renew automatically every three months — do not delete the
   certificate configuration.

### 3.6 Health checks

`config/cloud66/service.yml` configures the Kubernetes probes:

```yaml
health:
  startup:
    type: http
    endpoint: /up
    port: 3000
    initial_delay: 20
    period: 5
    failure_threshold: 30
  ready:
    type: http
    endpoint: /up
    port: 3000
    initial_delay: 10
    period: 5
    failure_threshold: 3
  alive:
    type: http
    endpoint: /up
    port: 3000
    initial_delay: 30
    period: 10
    failure_threshold: 3
```

- **startup** gives a cold container up to 2.5 minutes to boot (the first
  boot loads the schema) before the liveness probe may kill it.
- **ready** decides when a new pod receives traffic, which is what makes the
  deployment zero-downtime: the old pods keep serving until the new ones are
  healthy.
- **alive** restarts a container that stops answering.

The application answers `GET /up` with `200` and an empty green page, and the
path is excluded from the SSL redirect (`config.silence_healthcheck_path`).

For the post-deployment availability check of ActiveProtect, add the
following to `.cloud66/manifest.yml`:

```yaml
production:
  docker:
    configuration:
      activeprotect:
        health_check:
          endpoint: /up
          accept: ["200"]
          timeout: 5
          cooldown: 60
```

### 3.7 Scaling

- **More replicas:** *Application → Services → web → Desired instances*. Two
  replicas are enough to survive a node failure; each replica runs its own
  Puma process.
- **More capacity:** *Servers → Kubernetes cluster servers → Add worker*.
- The application is stateless (sessions are in cookies, images are URLs), so
  replicas can be added freely.
- Keep the number of database connections in check:
  `replicas × WEB_CONCURRENCY × RAILS_MAX_THREADS` must stay below the
  PostgreSQL `max_connections` of the managed database.

### 3.8 Background jobs

Procfiles are ignored for containerised applications, so a background worker
has to be a **second service** that uses the same image:

```yaml
services:
  worker:
    git_url: https://github.com/mislamdev/itransition-project1.git
    git_branch: main
    dockerfile_path: Dockerfile
    command: bin/rails runner 'Rails.application.executor.wrap { loop { sleep 60 } }'
```

Stockroom does not need a worker today (ActiveJob runs in-process and the
discussions are refreshed by the client), so create this service only when you
add jobs that must run outside a request.

### 3.9 Continuous deployment from GitHub Actions

Add a workflow that asks Cloud 66 to redeploy after the tests pass:

```yaml
name: Deploy to Cloud 66
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - name: Deploy
        run: cx deploy --stack stockroom
        env:
          C66_API_KEY: ${{ secrets.C66_API_KEY }}
          C66_APP_KEY: ${{ secrets.C66_APP_KEY }}
```

Create the keys in the Cloud 66 dashboard under *Account Settings → API keys*
and store them as repository secrets. Alternatively enable
**Deploy → Settings → Continuous Deployment** in the dashboard, which
redeploys on every push to the connected branch.

### 3.10 Toolbelt reference

```bash
cx login                                     # authenticate
cx stacks list                               # list the applications
cx stacks info --stack stockroom             # details and URLs
cx deploy --stack stockroom                  # deploy the current branch
cx logs --stack stockroom --follow           # tail the application log
cx env-vars list --stack stockroom          # list the variables
cx env-vars upload --stack stockroom vars   # upload a KEY=value file
cx services list --stack stockroom           # list the services and replicas
cx services scale --stack stockroom --service web --count 2
cx backups list --stack stockroom            # database backups
cx ssl --stack stockroom                     # inspect the certificate
cx run --stack stockroom --command "bin/rails db:seed"
```

## 4. Path B — Cloud 66 for Rails (virtual machines)

Use this path only if containers are not an option. It installs Ruby, Nginx
and the application server directly on a server in your cloud account.

### 4.1 Create the application

**New Application → Github app**, pick the repository, the branch `main`, the
environment `production`, and let Cloud 66 analyse the Gemfile. Cloud 66
detects Rails and provisions a web server, a database and an Nginx.

### 4.2 Manifest

The manifest of this repository is `.cloud66/manifest.yml`. It pins the Ruby
version, the asset pipeline and the health check:

```yaml
production:
  rails:
    configuration:
      ruby_version: 4.0.5
      asset_pipeline_enabled: true
      asset_pipeline_precompile: true
      health_check:
        protocol: 'http'
        host: 'localhost'
        port: 80
        endpoint: '/up'
        accept: ["200"]
  postgresql:
    configuration:
      version: 16
```

> **Ruby 4.0.5 on the virtual machine product.** Cloud 66 installs Ruby from
> its own catalogue. If Ruby 4.0.5 is not offered for your Ubuntu version,
> either use a container (Path A) or open a support query — do not pin an
> older Ruby in the manifest while the application requires 4.0.5.

### 4.3 Web server

Cloud 66's default server is Passenger. Stockroom is configured for Puma, so
the repository contains a `Procfile`:

```
custom_web: bundle exec puma -b unix:///tmp/web_server.sock --pidfile /tmp/web_server.pid
```

The socket and the pid file are the ones the Cloud 66 Nginx expects;
`config/puma.rb` uses `CUSTOM_WEB_SOCKET_FILE` and `CUSTOM_WEB_PID_FILE` when
they are set instead.

### 4.4 Deploy hooks

`.cloud66/deploy_hooks.yml` runs the migrations after a deployment and clears
the Bootsnap cache:

```yaml
production:
  after_symlink:
    - source: /.cloud66/scripts/migrate.sh
      destination: /tmp/migrate.sh
      target: rails
      execute: true
      run_on: all_servers
      apply_during: all
```

The script is `.cloud66/scripts/migrate.sh`.

> Cloud 66 runs `rake db:migrate` by itself during every deployment and waits
> for it before the other servers continue. The hook above is only needed when
> the automatic migrations are switched off (`cx settings set --stack
> <application> auto_migrate false`).

### 4.5 Environment variables

The same variables as in path A, entered in **Settings → Environment Variables**.
Cloud 66 generates the database variables automatically; append `?seeds=false`
to the database URL.

### 4.6 SSL

**Application → SSL Certificate → Add SSL Certificate → Standard**, as in
path A. The Nginx of Cloud 66 terminates TLS and forwards to Puma over the
Unix socket, so `ASSUME_SSL=true` is the correct setting here as well.

### 4.7 Scaling and the load balancer

Add a **load balancer** (*Load Balancers → Add Load Balancer*) before adding
more than one web server, then scale the web servers in *Web → Add Web
Server*. Cloud 66 runs `rake db:migrate` automatically on each deployment and
waits for it before the other servers continue.

## 5. Post-deployment checklist

1. `curl -I https://<domain>/up` → `200`.
2. `curl -I https://<domain>/` → `200` (the guest dashboard).
3. Open the application and create the first real administrator account, or
   promote an existing user from **Administration → Users**.
4. If you used `seeds=false`, no demo account exists — good. If you seeded
   deliberately, **change the passwords of `admin@example.com` and
   `demo@example.com` immediately**.
5. Check the logs: `cx logs --stack stockroom --follow`.
6. Test the search with a word that only exists in an item description — it
   proves that the `tsvector` columns and the GIN indexes are in place.
7. Configure the OAuth callback URLs with Google and Facebook if you want
   social sign-in.
8. Enable the database backups (**Data Sources → Postgres → Backups**) and
   test a restore.
9. Point a monitoring service at `https://<domain>/up`.

## 6. Operations runbook

| Task | Command / place |
|---|---|
| Deploy the current branch | `cx deploy --stack stockroom` |
| Roll back to the previous image | Dashboard → *Timeline* → the previous build → *Redeploy* |
| Scale the web service | `cx services scale --stack stockroom --service web --count 3` |
| Tail the log | `cx logs --stack stockroom --follow` |
| Run a one-off command | `cx run --stack stockroom --command "bin/rails ..."` |
| Open a Rails console | `cx run --stack stockroom --command "bin/rails console"` |
| Back up the database | `cx backups new --stack stockroom` |
| Rotate `SECRET_KEY_BASE` | Set a new value in the dashboard, deploy — **all sessions are invalidated** |
| Rotate the OAuth secrets | Update the provider and the dashboard variable, then deploy |

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `PG::UndefinedTable: relation "inventories" does not exist` | The schema was never prepared | The database URL is missing or wrong. Check `DATABASE_URL` in *Settings → Environment Variables* and redeploy; `db:prepare` loads `db/structure.sql`. |
| The container restarts in a loop | The database is unreachable | The entry point waits 60 seconds for the database. If it still fails, check the credentials and the firewall between the cluster and the database server. |
| `PG::TooManyConnections` | Too many connections | Lower `RAILS_MAX_THREADS` or `WEB_CONCURRENCY`, or raise `max_connections` of the managed database. |
| Every page is a 500 after the first request | A migration failed half way | Run `cx run --stack stockroom --command "bin/rails db:migrate:status"` and read the error in the logs. |
| The stylesheets are missing (404) | Assets were not precompiled | The image build failed in the asset step. Check the build log of the deployment. |
| `Force SSL` redirect loop | `FORCE_SSL=true` without `ASSUME_SSL=true` behind the proxy | Set both to `true`. |
| The OAuth callback returns `redirect_uri_mismatch` | The callback URL does not match | Use `https://<domain>/auth/google_oauth2/callback` (Google) or `https://<domain>/auth/facebook/callback` (Facebook). |
| The search finds nothing | The database was created without the search vectors | `db:prepare` loads `db/structure.sql`, which contains the `tsvector` columns and the GIN indexes. Verify with `cx run --stack stockroom --command "bin/rails runner 'puts ActiveRecord::Base.connection.columns(:items).map(&:name).grep(/search/).inspect'"`. |
| The build fails on `bundle install` | The lock file has no matching platform | `Gemfile.lock` contains `x86_64-linux` and `aarch64-linux`; keep it that way when you update the gems. |

## 8. Security notes

- `SECRET_KEY_BASE` is never committed: use `AUTO_GENERATE_64` or keep it in
  the Cloud 66 environment variables.
- `config/master.key` is **not** in the repository. If you need the encrypted
  credentials (`config/credentials.yml.enc`), set `RAILS_MASTER_KEY` as an
  environment variable; otherwise supply `SECRET_KEY_BASE` only.
- The application runs as the non-root user `rails` (uid 1000) inside the
  container.
- The database is only reachable from the cluster; do not open port 5432 to
  the internet.
- `RAILS_LOG_LEVEL=debug` logs request parameters (the password filter covers
  the usual suspects, but not everything) — keep it at `info`.
- The application filters `:email`, `:password` (`:passw`), `:secret`,
  `:token` and friends from the logs
  (`config/initializers/filter_parameter_logging.rb`).
- The demo credentials in `db/seeds.rb` are public knowledge — never let them
  reach a production database.
