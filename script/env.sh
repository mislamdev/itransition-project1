# Environment of the development setup.
#
# Source it before running the application inside the workspace sandbox:
#
#   source script/env.sh
#
# The gems of the application live in vendor/bundle, the toolchain (the
# rails executable) in vendor/gems; both are inside the workspace, so that
# nothing has to be written outside of it.
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export GEM_HOME="$(pwd)/vendor/gems"
export GEM_PATH="$(pwd)/vendor/gems:/opt/homebrew/lib/ruby/gems/4.0.0"
export BUNDLE_USER_HOME="$(pwd)/.bundle"
export BUNDLE_PATH="$(pwd)/vendor/bundle"
