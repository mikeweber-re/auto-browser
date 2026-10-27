#!/usr/bin/env bash
# Replay: __FLOW__
# __DESCRIPTION__
# Key: __KEY__
#
#   auto-browser run <this dir>                  # headless
#   AB_HEADED=1 auto-browser run <this dir>      # watch it
#   BASE_URL=http://localhost:4000 auto-browser run <this dir>

# shellcheck source=/dev/null
source "$(auto-browser lib)"

step "log in"
login

step "open __START_PATH__"
ab open "${BASE_URL}__START_PATH__" >/dev/null
ab wait --load networkidle >/dev/null

# One step() per user-visible action. Stable locators only, never @eN refs.
# step "fill the form"
# ab find label "Email" fill "test+$RUN_ID@example.com" >/dev/null
# ab find role button click --name "Save" >/dev/null
# expect_text "Saved"
# shot saved

pass
