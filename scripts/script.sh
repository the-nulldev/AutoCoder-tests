#!/bin/bash

# Get inputs from the environment
GITHUB_TOKEN="$1"
REPOSITORY="$2"
ISSUE_NUMBER="$3"
OPENAI_API_KEY="$4"

# Get the issue body
ISSUE_BODY=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
"https://api.github.com/repos/$REPOSITORY/issues/$ISSUE_NUMBER" | jq -r .body)

# Prepare the messages array for the ChatGPT API
MESSAGES_JSON=$(jq -n --arg body "$ISSUE_BODY" '[{"role": "user", "content": $body}]')

# Extract the filename from the first line of the issue body
FILENAME=$(echo "$ISSUE_BODY" | head -n 1 | grep -oP '^Filename: \K.*')

# Check if a filename was actually found
if [[ -z "$FILENAME" ]]; then
    echo "No filename found in the issue body."
    exit 1
fi

# Check if the filename contains a valid extension and is not just a plain text
if ! [[ "$FILENAME" =~ \. ]]; then
    echo "Invalid filename ($FILENAME) found in the issue body."
    exit 1
fi

# Send the issue content to the ChatGPT model (OpenAI API)
RESPONSE=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"gpt-3.5-turbo\", \"messages\": $MESSAGES_JSON, \"max_tokens\": 400}")

# Extract the content from the assistant's message
CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')

# Save the generated content to the file
echo "$CONTENT" > "$FILENAME"
echo "The code has been written to $FILENAME"