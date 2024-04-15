#!/bin/sh
set -e

# Prepare environment here if needed

# Start web server
echo 'Starting the web server...'
python manage.py runserver 0.0.0.0:8000
