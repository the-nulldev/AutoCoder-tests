#!/bin/bash

SLACK_WEBHOOK_URL=$1  
MESSAGE=$2            
CHANNEL=$3            

PAYLOAD=$(cat <<EOF
{
  "text": "$MESSAGE",
  "channel": "$CHANNEL",
  "username": "GitHub Actions",
  "icon_emoji": ":rocket:"
}
EOF
)
curl -X POST -H 'Content-type: application/json' --data "$PAYLOAD" "$SLACK_WEBHOOK_URL"
