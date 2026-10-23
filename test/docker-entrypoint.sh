#!/bin/sh
set -eu

# Keep test writes inside the container and leave the source checkout untouched.
cp -R /source/. /testplugin/
chown -R vimtest:vimtest /testplugin
exec runuser -u vimtest -- "$@"
