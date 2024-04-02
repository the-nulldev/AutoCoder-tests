#!/bin/sh

chmod +x /app/entrypoint.sh

echo 'Starting the web service...'

exec "$@"
