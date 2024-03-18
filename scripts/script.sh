#!/bin/bash

# Get inputs from the environment
GITHUB_TOKEN="$1"
REPOSITORY="$2"
ISSUE_NUMBER="$3"
OPENAI_API_KEY="$4"

# Get the issue labels using the GitHub API
LABELS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
"https://api.github.com/repos/$REPOSITORY/issues/$ISSUE_NUMBER/labels")

# Check if the issue has the autocoder-bot label
if echo "$LABELS" | jq -e '.[] | select(.name == "autocoder-bot")' > /dev/null; then
    # Get the issue body
    ISSUE_BODY=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPOSITORY/issues/$ISSUE_NUMBER" | jq -r .body)

    # Send the issue content to ChatGPT (OpenAI API)
    RESPONSE=$(curl -s -X POST "https://api.openai.com/v1/engines/davinci-codex/completions" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"prompt\": \"$ISSUE_BODY\", \"max_tokens\": 1000}")

    # Print the response from ChatGPT
    echo "Response from ChatGPT: $RESPONSE"
fi
