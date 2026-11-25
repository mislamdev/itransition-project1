# Deploying Stockroom on Render

[Render](https://render.com) runs the application in a container of its own.
This project is deployed with the **Docker runtime**: Render builds the
`Dockerfile` of the repository into an image and runs it.

The files of this deployment are:

| File | Purpose |
|---|---|
| `render.yaml` | Blueprint: the web service and the PostgreSQL database in one step |
| `Dockerfile` | The image: the gems and the assets are compiled while it is built |
| `bin/docker-entrypoint` | Prepares the database and starts Puma on `$PORT` |

## 1. The blueprint (recommended)

1. Push `render.yaml` to the repository (it is part of the repository).
2. In the [Render dashboard](https://dashboard.render.com): **New → Blueprint**
   and select the repository.
3. Render asks for the values that are marked with `sync: false`:
   - `SECRET_KEY_BASE` — generate one with `openssl rand -hex 64` and paste
     it. It signs the session cookies, so it must stay the same over the
     deployments.
   - `ADMIN_EMAIL` / `ADMIN_PASSWORD` — the first administrator of the empty
     database.
   - `APP_HOST` / `APP_HOSTS` — the public name of the application, for
     example `stockroom.onrender.com`. Leave them empty to accept every
     host.
   - The four OAuth values, if the sign in with Google or Facebook should
     work.
4. Render creates the database and the web service and starts the first
   deployment. The address of the application is
   `https://stockroom.onrender.com`.

The database and the web service have to be in the same region. The free
plan of Render sleeps after 15 minutes of inactivity; the first request
after that takes a moment.

## 2. The dashboard, step by step

If you do not want to use the blueprint, create the services by hand.

### The database

**New → Postgres** → name it `stockroom-db` → choose the region and the
plan. After the deployment, copy the **internal database URL** (it starts
with `postgresql://`).

### The web service

**New → Web Service** → connect the repository and set:

| Setting | Value |
|---|---|
| *Language* | **Docker** |
| *Dockerfile Path* | `./Dockerfile` (the default) |
| *Docker Context* | `.` (the default) |
| *Docker Command* | empty — the `CMD` of the image is used |
| *Region* | The region of the database |
| *Health Check Path* | `/up` |

The environment variables:

| Key | Value |
|---|---|
| `DATABASE_URL` | The internal database URL of the PostgreSQL database |
| `SECRET_KEY_BASE` | A fixed random value (`openssl rand -hex 64`) |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | The first administrator of the empty database |
| `RAILS_LOG_LEVEL` | `info` |
| `ASSUME_SSL` | `true` — Render terminates TLS and sends `X-Forwarded-Proto: https` |
| `FORCE_SSL` | `true` — secure cookies and HSTS |
| `APP_HOST` / `APP_HOSTS` | The public name of the application (optional) |
| `GOOGLE_OAUTH_*` / `FACEBOOK_*` | Optional, both values of a pair |

Render sets `PORT=10000` and `RAILS_ENV=production` by itself.

> **A note about the build arguments.** Render turns the environment
> variables of a Docker service into build arguments. The `Dockerfile` of
> this repository only uses `RUBY_VERSION` as an argument, so no secret
> ends up in the image.

## 3. What happens in the container

1. **The image is built.** The build stage installs the gems (the
   development and the test groups are skipped by `BUNDLE_DEPLOYMENT=1`) and
   compiles the assets. The final stage contains the application, the gems
   and the Bootsnap cache, and runs as the non-root user `rails`.
2. **The container starts.** `bin/docker-entrypoint` waits for the database
   (`pg_isready`, 30 attempts of 2 seconds), runs `bin/rails db:prepare`
   (the schema is created from `db/structure.sql` when the database is
   empty, the pending migrations are run afterwards), creates the
   administrator from `ADMIN_EMAIL` / `ADMIN_PASSWORD` and starts Puma.
3. **Puma listens on `0.0.0.0:$PORT`** (10000 on Render) — Render finds the
   port with a scan and sends the traffic to it.
4. **The health check** hits `/up`, which answers with `200` as soon as the
   application is booted.

The demo data of `db/seeds.rb` is not loaded: the seeds file stops itself
in the production environment (`ALLOW_SEEDS=true` loads it anyway). The
database URL does not need the `?seeds=false` option here.

## 4. The first administrator

The entry point creates the account from the environment on the first
start. An account that exists already is only promoted to an
administrator — its password is never changed, so it is safe to leave the
variables in place.

The same task can be run by hand (over SSH, in a one-off job or in the
shell of a paid plan):

```bash
cd /rails
bundle exec rails "admin:create[admin@example.com,a-strong-password]"
```

The application lives in `/rails` inside the image.

## 5. The native Ruby runtime (alternative)

Render can also build the repository with its own Ruby runtime. Then the
build command and the start command of the dashboard are used instead of
the image:

| Setting | Value |
|---|---|
| *Language* | Ruby |
| *Build Command* | `./bin/render-build.sh` |
| *Start Command* | `./bin/rails server` |
| *Health Check Path* | `/up` |

`bin/render-build.sh` installs the gems, compiles the assets and prepares
the database. Two differences to the Docker runtime:

- **`.ruby-version` contains only the version number** (`4.0.5`), the format
  that Render, rbenv and asdf expect. The RVM format (`ruby-4.0.5`) makes
  the build of Render fail.
- **The migrations run in the build command**, because the pre-deploy
  command of Render needs a paid compute plan. Move `bin/rails db:prepare`
  to the pre-deploy command on a paid plan.

The environment variables are the same, plus `WEB_CONCURRENCY=2` — Render
picks the number of workers from the CPUs of the instance, which is too
many for a small plan.

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Exited with status 2` | The build or the start command failed | The log of the deploy shows the failing line. With the native runtime the most common cause in this project was `.ruby-version`: Render expects `4.0.5`, not `ruby-4.0.5`. |
| `Port scan timeout reached, no open ports detected` | The application does not listen on a TCP port | With the Docker runtime the image starts Puma on `0.0.0.0:$PORT` ✓. With the native runtime the start command has to be `bin/rails server`. A start command that binds a Unix socket (`-b unix:///tmp/web_server.sock`) leaves Render without a port. |
| `PG::ConnectionNotEstablished` | The database URL is wrong or the database is not reachable | Use the **internal** URL of the database, and check that the database and the service are in the same region. |
| `ActiveRecord::NoDatabaseError` | The database exists but the schema is missing | The entry point runs `db:prepare`; check the log for the output of the task. |
| `Missing secret_key_base for 'production' environment` | `SECRET_KEY_BASE` is not set | Set it in the environment of the service. |
| The stylesheets are missing | The assets were not compiled | They are compiled while the image is built; check the build log of the deploy. |
| The administrator does not exist | `ADMIN_EMAIL` / `ADMIN_PASSWORD` were not set | Run `bin/rails "admin:create[email,password]"` in the shell, or set the variables and redeploy. |
| The application sleeps and the first request is slow | The free plan sleeps after 15 minutes | Expected on the free plan; use a paid plan for a production application. |
| The sessions are lost after every deployment | The secret key base changes | `SECRET_KEY_BASE` must be a fixed value. `generateValue: true` in the blueprint generates a new one on every sync. |
