# Deploying Stockroom on DOM Cloud

[DOM Cloud](https://domcloud.co) runs the application on a shared Rocky
Linux server, with NGINX in front of [Phusion Passenger](https://www.phusionpassenger.com/).
The deployment is a single YAML script that DOM Cloud executes over SSH.

The complete script lives in [`config/domcloud/deploy.yml`](../../config/domcloud/deploy.yml).

## 1. Before the first deployment

1. **Point the domain at DOM Cloud.** The deployment asks Let's Encrypt for a
   certificate, which only works when the domain already points to the
   server. The IP address is shown in the portal. If the domain does not
   resolve yet, the certificate is skipped (the log says `none of the
   certificate names could be resolved!`) and the site stays on HTTP until
   you run the deployment again.
2. **Create the website** in the [DOM Cloud portal](https://my.domcloud.co).
   The plan decides which features are available; the PostgreSQL database and
   the SSL certificate need a paid plan.
3. **Open the deployment editor:** *Setup → Deploy → Add a deployment task*,
   paste the content of `config/domcloud/deploy.yml` and run it.

## 2. What the script does

| Part | Effect |
|---|---|
| `source` | Clones `mislamdev/itransition-project1` (branch `main`) into `~/public_html` |
| `features: ruby 4.0.5` | Installs the Ruby version of `.ruby-version` with RVM (DOM Cloud ships a prebuilt package, so it takes seconds) |
| `features: postgresql` | Creates the managed PostgreSQL database and provides `$DATABASE` and `$PGPASSWD` to the commands |
| `features: ssl always` | Requests the Let's Encrypt certificate and redirects HTTP to HTTPS permanently |
| `nginx.passenger` | Serves the application with Passenger; `run.sh` starts Puma on the port that Passenger assigns |
| `commands` | Installs the gems, prepares the database, compiles the assets and restarts the application |

The commands run in this order:

1. `rm -f Procfile` — the `Procfile` of the repository belongs to the
   [Cloud 66](cloud66.md) deployment; Passenger would start Puma with the
   wrong socket.
2. `domcloud_env.sh` — writes `~/stockroom.env` with the environment of the
   application. The file is outside of `public_html` (which is emptied on
   every deployment) and it keeps the `SECRET_KEY_BASE`, so that the
   sessions of the users survive a deployment.
   The variables of DOM Cloud (`$USERNAME`, `$PGPASSWD`, `$DATABASE`,
   `$DOMAIN`) are **not exported** by the deployment shell: they are plain
   shell variables. A command sees them, but a script that runs in its own
   process does not. The script therefore receives them as arguments
   (`bash domcloud_env.sh "$USERNAME" "$PGPASSWD" "$DATABASE" "$DOMAIN"`).
3. `run.sh` — the start command of Passenger. It loads `~/stockroom.env`
   and runs `bundle exec puma`; `config/puma.rb` listens on the `PORT`
   variable that Passenger sets.
4. `gem install bundler` — the bundler version of `Gemfile.lock`.
5. `bundle install` — without the `development` and the `test` groups. The
   native gems (`pg`, `nokogiri`, `commonmarker`, `thruster`) are installed
   as prebuilt packages, so nothing is compiled.
6. `bundle exec rails db:prepare` — loads `db/structure.sql` when the
   database is still empty (it contains the `tsvector` columns and the GIN
   indexes of the full text search) and runs the pending migrations
   afterwards.
7. `bundle exec rails assets:precompile` — compiles the assets (Propshaft)
   into `public/assets`, where NGINX serves them.
8. `passenger-config restart-app ~` — restarts the application, so that it
   serves the new code.

### Why `?seeds=false` is part of the database URL

`db:prepare` loads `db/seeds.rb` when it creates the database, and the seeds
file contains demo accounts with public passwords (`admin@example.com` /
`administrator`). The Rails option `seeds=false` in the database URL switches
that off, so a production database never receives them.

## 3. The first administrator

The database is empty after the deployment, so create the first account over
SSH:

```bash
cd ~/public_html
. ~/stockroom.env
bundle exec rails runner 'u = User.find_or_initialize_by(email: "admin@example.com"); u.name = "Administrator"; u.admin = true; u.password = "a-strong-password"; u.save!; puts u.id'
```

Then sign in with that address and change the password in the settings.

## 4. Everyday work

| Task | Command (over SSH) |
|---|---|
| Deploy the current `main` | *Setup → Deploy → Run* in the portal |
| Restart the application | `passenger-config restart-app ~` (or `restart` to kill every process of the user) |
| Rails console | `cd ~/public_html && . ~/stockroom.env && bundle exec rails console` |
| Apply a migration | `cd ~/public_html && . ~/stockroom.env && bundle exec rails db:migrate` |
| Run the test suite | `cd ~/public_html && . ~/stockroom.env && bundle exec rails test` |
| The application log | *Check → Check Process Logs* in the portal |
| The state of the application | `passenger-status` |

The deployment stops at the first command that fails, and the log of the
portal shows the line that failed. The whole script has a time limit of 15
minutes.

## 5. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `❌ Error 1: failed at line ...` in the deployment log | A command failed | The log names the failing line. The most common cause is a missing database: check that the `postgresql` feature is enabled. |
| `PG::ConnectionNotEstablished: ... fe_sendauth: no password supplied` | The database URL was written without a password | The variables of DOM Cloud are not exported, so a script in its own process does not see `$PGPASSWD`. Pass them as arguments (see the script of this repository) and check `~/stockroom.env`. |
| `The PostgreSQL credentials are missing.` | The `postgresql` feature is not enabled | Add `- postgresql` to the features and run the deployment again. The database name is `$DATABASE`, the password is `$PGPASSWD`; both are shown in the portal under *Setup → Database*. |
| `none of the certificate names could be resolved!` | The domain does not point at DOM Cloud (yet) | The certificate is skipped, the site stays on HTTP. Point the domain at the IP address of the server (the portal shows it), wait until it resolves (`dig <domain>`) and run the deployment again. |
| The site shows the Passenger error page | The application does not start | `passenger-status` shows the reason. Usually a missing gem: run `bundle install` over SSH. |
| `PG::UndefinedTable: relation "inventories" does not exist` | The schema was never created | Run `bundle exec rails db:prepare` over SSH. |
| `cannot load such file -- rack (LoadError)` | The rack gem is missing | `gem install rack` (the application itself does not need it; Passenger does). |
| The stylesheets are missing | The assets were not compiled | `bundle exec rails assets:precompile` over SSH, then restart the application. |
| `PG::ConnectionBad` | Wrong credentials | The password must not contain characters that have to be escaped in a URL (`@`, `:`, `/`, `?`). DOM Cloud generates an alphanumeric password; if you changed it in the portal, change it back or URL-encode it in `~/stockroom.env`. |
| The redirect to HTTPS loops | `FORCE_SSL` without `ASSUME_SSL` | Both variables are written by `~/stockroom.env`; keep them together. |
| The OAuth callback fails | The callback URL does not match | Use `https://<domain>/auth/google_oauth2/callback` (Google) and `https://<domain>/auth/facebook/callback` (Facebook). |
| Every deployment loses the sessions | The `SECRET_KEY_BASE` changed | `~/stockroom.env` keeps it; do not delete that file. |

## 6. Notes

- `~/public_html` is emptied on every deployment. Everything that has to
  survive a deployment (the environment file, the installed gems) lives
  outside of it.
- The gems are installed into the gem directory of the RVM Ruby, so a
  second deployment only downloads what changed.
- The application is stateless: the sessions are in the cookies, the images
  of the inventories are cloud URLs. There is nothing to store on the disk.
- The database is reachable on `localhost:5432` only.
