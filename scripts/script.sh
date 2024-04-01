#!/bin/bash

# Get inputs from the environment
GITHUB_TOKEN="$1"
REPOSITORY="$2"
ISSUE_NUMBER="$3"
OPENAI_API_KEY="$4"

# Fetch issue details from GitHub API
RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
"https://api.github.com/repos/$REPOSITORY/issues/$ISSUE_NUMBER")

# Check if the curl command was successful
if [ $? -ne 0 ]; then
    echo "Failed to fetch issue details."
    exit 1
fi

# Check if the response contains an issue body
if echo "$RESPONSE" | grep -q '"body":'; then
    ISSUE_BODY=$(echo "$RESPONSE" | jq -r .body)
else
    echo "Issue body not found in response."
    echo "Response: $RESPONSE"
    exit 1
fi

# Check if the issue body is non-empty
if [[ -z "$ISSUE_BODY" ]]; then
    echo "Issue body is empty."
    exit 1
fi

FILENAME=$(echo "$ISSUE_BODY" | grep -oP '\d+\.\s+\K\S+' | head -n 1)

echo "Filename: $FILENAME"

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

# Prepare the messages array for the ChatGPT API
MESSAGES_JSON=$(jq -n --arg body "$ISSUE_BODY" '[{"role": "user", "content": $body}]')

RESPONSE=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"gpt-3.5-turbo\", \"messages\": $MESSAGES_JSON, \"max_tokens\": 400}")

# Extract the content from the assistant's message
CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')

# Save the generated content to the file
echo "$CONTENT" > "$FILENAME"
echo "The code has been written to $FILENAME"