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
ISSUE_BODY=$(echo "$RESPONSE" | jq -r .body)
if [[ -z "$ISSUE_BODY" ]]; then
    echo "Issue body is empty or not found in the response."
    exit 1
fi

# Define clear, concise instructions for GPT
INSTRUCTIONS="Based on the description below, please list the files and their specific directories and requirements for a production ready application. List the path with a digit such as 1. Dockerfile, 2. main.py, etc, followed by the corresponding code snippet enclosed in triple backticks. Stick to that description, don't add anything else. Make the minimum amount of assumptions about the rest of the repo. \n"

# Combine the instructions with the issue body to form the full prompt
FULL_PROMPT="$INSTRUCTIONS\n\n$ISSUE_BODY"

echo "$FULL_PROMPT"

# Prepare the messages array for the ChatGPT API, including the instructions
MESSAGES_JSON=$(jq -n --arg body "$FULL_PROMPT" '[{"role": "user", "content": $body}]')

echo "$MESSAGES_JSON"

# Send the prompt to the ChatGPT model (OpenAI API)
RESPONSE=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"gpt-3.5-turbo\", \"messages\": $MESSAGES_JSON, \"max_tokens\": 300}")

echo "$RESPONSE"

# Check if the API call was successful
if [ $? -ne 0 ]; then
    echo "Failed to get a response from OpenAI API."
    exit 1
fi

# Extract the content from the assistant's message
CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')

echo "$CONTENT"

# Regex pattern to match file names and code blocks
FILE_PATTERN="(?:([0-9]+)\. )?([^\n]+)\n```([^\`]+)```"

# Process each matched file and code block
while [[ $CONTENT =~ $FILE_PATTERN ]]; do
    FILENAME="${BASH_REMATCH[2]}"
    CODE_SNIPPET="${BASH_REMATCH[3]}"

    # Save the generated content to the file
    echo -e "$CODE_SNIPPET" > "$FILENAME"
    echo "The code has been written to $FILENAME"

    # Trim the first match from the content to avoid reprocessing
    CONTENT="${CONTENT#*$BASH_REMATCH}"
done

# Check if at least one file was processed
if [ -z "$FILENAME" ]; then
    echo "No valid filenames and code blocks found in the response."
    exit 1
fi
