# Deploying Stockroom on Render

[Render](https://render.com) runs the application in a container of its own:
either with the **native Ruby runtime** (the repository is built on Render's
build image) or with the **Docker runtime** (the `Dockerfile` of the
repository is built into an image).

The files of this deployment are:

| File | Purpose |
|---|---|
| `render.yaml` | Blueprint: the web service and the PostgreSQL database in one step |
| `bin/render-build.sh` | The build command: gems, assets and database |

## 1. The blueprint (recommended)

1. Push `render.yaml` to the repository (it is part of the repository).
2. In the [Render dashboard](https://dashboard.render.com): **New → Blueprint**
   and select the repository.
3. Render asks for the values that are marked with `sync: false`:
   - `SECRET_KEY_BASE` — generate one with `openssl rand -hex 64` and paste
     it. It signs the session cookies, so it must stay the same over the
     deployments.
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

If you do not want to use the blueprint, create the services by hand:

### The database

**New → Postgres** → name it `stockroom-db` → choose the region and the
plan. After the deployment, copy the **internal database URL** (it starts
with `postgresql://`).

### The web service

**New → Web Service** → connect the repository and set:

| Setting | Value |
|---|---|
| *Language* | Ruby (or Docker, see below) |
| *Region* | The region of the database |
| *Build Command* | `./bin/render-build.sh` |
| *Start Command* | `./bin/rails server` |
| *Health Check Path* | `/up` |
| *Environment* | The variables below |

The environment variables:

| Key | Value |
|---|---|
| `DATABASE_URL` | The internal database URL of the PostgreSQL database |
| `SECRET_KEY_BASE` | A fixed random value (`openssl rand -hex 64`) |
| `WEB_CONCURRENCY` | `2` — Render picks the number of workers from the CPUs of the instance, which is too many for a small plan |
| `RAILS_LOG_LEVEL` | `info` |
| `ASSUME_SSL` | `true` — Render terminates TLS and sends `X-Forwarded-Proto: https` |
| `FORCE_SSL` | `true` — secure cookies and HSTS |
| `APP_HOST` / `APP_HOSTS` | The public name of the application (optional) |
| `GOOGLE_OAUTH_*` / `FACEBOOK_*` | Optional, both values of a pair |

Render sets `RAILS_ENV=production`, `PORT=10000` and `RAILS_SERVE_STATIC_FILES=true`
by itself.

## 3. The Docker runtime

The repository has a `Dockerfile`, so Render can build the image itself:
choose **Docker** as the runtime instead of Ruby. Then the build command and
the start command are ignored — the image contains everything:

- the gems and the assets are compiled while the image is built,
- the entry point (`bin/docker-entrypoint`) waits for the database and runs
  `db:prepare` before Puma starts,
- Puma listens on `0.0.0.0:$PORT` ✓.

The environment variables are the same. `RAILS_SERVE_STATIC_FILES` is not
needed (the assets are in the image).

## 4. The first administrator

The database is empty after the deployment, so create the first account.
Open the shell of the service (*Shell* in the dashboard, paid plans) or run
the command in a one-off job:

```bash
cd /opt/render/project/src
bundle exec rails runner 'u = User.find_or_initialize_by(email: "admin@example.com"); u.name = "Administrator"; u.admin = true; u.password = "a-strong-password"; u.save!; puts u.id'
```

Then sign in with that address and change the password in the settings.

## 5. What is different from the other platforms

- **The `Procfile` of the repository is ignored.** It belongs to the
  [Cloud 66](cloud66.md) deployment, where Passenger starts Puma on a Unix
  socket. Render uses the start command of the dashboard (`bin/rails server`)
  and expects a TCP port.
- **`.ruby-version` contains only the version number** (`4.0.5`), the format
  that Render, rbenv and asdf expect. The RVM format (`ruby-4.0.5`) makes
  the build of Render fail.
- **The demo data of `db/seeds.rb` is skipped in production.** The seeds
  file stops itself when `RAILS_ENV=production` (set `ALLOW_SEEDS=true` to
  load it anyway). The database URL does not need the `?seeds=false` option
  here.
- **The migrations run in the build command** (`bin/render-build.sh`),
  because the pre-deploy command of Render needs a paid compute plan. Move
  `bin/rails db:prepare` to the pre-deploy command on a paid plan.

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Exited with status 2` | The build or the start command failed | The log of the deploy shows the failing line. The most common cause in this project was `.ruby-version`: Render expects `4.0.5`, not `ruby-4.0.5`. |
| `Port scan timeout reached, no open ports detected` | The application does not listen on a TCP port | The start command has to be `bin/rails server` (or the Docker image, which binds `0.0.0.0:$PORT`). A start command that binds a Unix socket (`-b unix:///tmp/web_server.sock`) leaves Render without a port. |
| `PG::ConnectionNotEstablished` | The database URL is wrong or the database is not reachable | Use the **internal** URL of the database, and check that the database and the service are in the same region. |
| `ActiveRecord::NoDatabaseError` | The database exists but the schema is missing | Run `bin/rails db:prepare` in the build command (it is there) or in a one-off job. |
| `Missing secret_key_base for 'production' environment` | `SECRET_KEY_BASE` is not set | Set it in the environment of the service. |
| The stylesheets are missing | The assets were not compiled | `bin/render-build.sh` compiles them; check that the build command is the script and not only `bundle install`. |
| The application sleeps and the first request is slow | The free plan sleeps after 15 minutes | Expected on the free plan; use a paid plan for a production application. |
| The sessions are lost after every deployment | The secret key base changes | `SECRET_KEY_BASE` must be a fixed value. `generateValue: true` in the blueprint generates a new one on every sync. |
