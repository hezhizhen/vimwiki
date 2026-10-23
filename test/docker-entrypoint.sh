#!/bin/sh
set -eu

# Keep test writes inside the container and leave the source checkout untouched.
cp -R /source/. /testplugin/
chown -R vimtest:vimtest /testplugin

if [ -n "${VADER_OUTPUT_FILE:-}" ]; then
  # Vader must write as vimtest; reopening Docker's root-owned stderr can fail.
  export VADER_OUTPUT_FILE=/home/vimtest/vader.log
  result=0
  runuser -u vimtest -- "$@" || result=$?
  if [ ! -f "$VADER_OUTPUT_FILE" ]; then
    echo 'Vader did not produce a test log.' >&2
    exit 1
  fi
  cat "$VADER_OUTPUT_FILE" >&2
  exit "$result"
fi

exec runuser -u vimtest -- "$@"
