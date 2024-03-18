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

    # Prepare the messages array for the ChatGPT API
    MESSAGES_JSON=$(jq -n --arg body "$ISSUE_BODY" '[{"role": "user", "content": $body}]')

    # Send the issue content to the ChatGPT model (OpenAI API)
    RESPONSE=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"gpt-3.5-turbo\", \"messages\": $MESSAGES_JSON, \"max_tokens\": 4096}")

    # Extract the content from the assistant's message
    CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')

    # Use a regex to extract the filename which is expected to follow the pattern "# File name: filename.ext"
    FILENAME=$(echo "$CONTENT" | grep -oP '(?<=# File name: ).*')

    # Extract the code, removing the first line that contains the filename
    CODE=$(echo "$CONTENT" | sed '1d')

    # If a filename has been extracted, create the file with the code content
    if [ -n "$FILENAME" ]; then
        echo "$CODE" > "$FILENAME"
        echo "File '$FILENAME' has been created with the generated code."
    else
        echo "Filename could not be extracted from the response."
    fi
fi
