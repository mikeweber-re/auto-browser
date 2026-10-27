#!/usr/bin/env bash
# Log a test user in without a browser and print the session cookies.
#
#   login.sh [email] --cookies
#
# Prints EXACTLY ONE thing on stdout: a JSON array of {name, value} cookies.
# Diagnostics go to stderr. Never opens a browser: the caller sets the cookies
# on its own isolated browser session.
#
# Typical bodies: call a test-only endpoint that mints a session, use your auth
# provider's admin API to create one, or POST to the login form with curl and
# collect the Set-Cookie headers. Delete this file and set scripts.login to null
# if the app has no login, or if login can only happen through the UI (then
# describe the steps in the config's "notes").
set -euo pipefail
EMAIL=""
for a in "$@"; do
  case "$a" in
    --cookies) ;;
    *) EMAIL=$a ;;
  esac
done
echo "TODO: mint a session for ${EMAIL:-the default user} and print its cookies" >&2
exit 1
