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

    # Prepare the prompt for the Codex API, including context from the issue body and repository files if needed
    PROMPT="I have the following repository $REPOSITORY. Can you help me generate files as per the issue body below?\n\n$ISSUE_BODY"

    # Send the prompt to the Codex model (OpenAI API)
    RESPONSE=$(curl -s -X POST "https://api.openai.com/v1/completions" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"code-davinci-002\", \"prompt\": \"$PROMPT\", \"max_tokens\": 1500}")

    # Print the response from Codex
    echo "Response from Codex: $RESPONSE"
fi
