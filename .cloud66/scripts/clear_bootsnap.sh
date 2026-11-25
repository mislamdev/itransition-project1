#!/bin/bash
#
# Removes the Bootsnap cache of the previous release.
#
# The cache is written by the user that compiled it. A cache that was left
# behind by another release makes the application boot very slowly, so it is
# cleared before the web server is restarted.

set -e

rm -rf "$STACK_PATH/tmp/cache/bootsnap*"
