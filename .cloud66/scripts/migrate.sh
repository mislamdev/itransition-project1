#!/bin/bash
#
# Runs the pending database migrations on Cloud 66 (virtual machine path).
#
# The script is called by the deploy hook ".cloud66/deploy_hooks.yml" after
# the new code has been checked out.

set -e

cd "$STACK_PATH"

bundle exec rake db:migrate
