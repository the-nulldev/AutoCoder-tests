chmod +x entrypoint.sh

echo 'Starting the web server...'
exec $@
