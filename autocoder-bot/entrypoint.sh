#!/bin/sh
chmod +x /app/entrypoint.sh
echo 'Starting the web server...'
python app.py
