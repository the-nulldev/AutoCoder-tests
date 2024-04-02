#!/bin/sh

chmod +x ./entrypoint.sh

echo 'Starting web server...'

exec "$@"
