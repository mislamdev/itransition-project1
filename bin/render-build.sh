#!/usr/bin/env bash
#
# The build command of Render.
#
# Render runs it before every deploy:
#   Settings -> Build -> Build Command: ./bin/render-build.sh
#
# It installs the gems, compiles the assets and prepares the database. The
# database is prepared here (and not in a pre-deploy command) because the
# pre-deploy command needs a paid compute plan.

set -o errexit
set -o pipefail

bundle install
bin/rails assets:precompile
bin/rails assets:clean
bin/rails db:prepare
