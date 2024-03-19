#!/bin/bash

# Get the issue labels using the GitHub API
LABELS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
"https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/labels")

# Check if the API response is valid JSON
if ! echo "$LABELS" | jq empty; then
    echo "Error: Invalid API response"
    exit 1
fi

# Check if the issue has the autocoder-bot label
if echo "$LABELS" | jq -e '.[] | select(.name == "autocoder-bot")' > /dev/null; then
    # get issue body
    ISSUE_BODY=$(curl -s -H "Authorization : token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER" | jq -r '.body')

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

    # return the file name and the code to the GitHub Actions worflow as an output
    echo "::set-output name=filename::$FILENAME"
    echo "::set-output name=code::$CODE"

fi