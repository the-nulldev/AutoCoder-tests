#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Log each command for debugging purposes
set -x

# Get inputs from the environment
GITHUB_TOKEN="$1"
REPOSITORY="$2"
ISSUE_NUMBER="$3"
OPENAI_API_KEY="sk-a4m6p3hsf6dj77u1pyitamcqdaqciwwc"

# Base URL for the mock OpenAI API
OPENAI_API_BASE="https://mockgpt.wiremockapi.cloud/v1"

# Directory to save generated files
OUTPUT_DIR="autocoder-bot"

# Function to fetch issue details from GitHub API
fetch_issue_details() {
    curl -s -H "Authorization: token $GITHUB_TOKEN" \
         "https://api.github.com/repos/$REPOSITORY/issues/$ISSUE_NUMBER"
}

# Function to send a prompt to the ChatGPT model (OpenAI API)
send_prompt_to_chatgpt() {
    curl -s -X POST "$OPENAI_API_BASE/chat/completions" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$1"
}

# Function to save code snippet to a file
save_to_file() {
    local filename="$OUTPUT_DIR/$1"
    local code_snippet="$2"

    mkdir -p "$(dirname "$filename")"
    echo -e "$code_snippet" > "$filename"
    echo "The code has been written to $filename"
}

# Fetch and process issue details
RESPONSE=$(fetch_issue_details)
ISSUE_BODY=$(echo "$RESPONSE" | jq -r .body)

if [[ -z "$ISSUE_BODY" ]]; then
    echo 'Issue body is empty or not found in the response.'
    exit 1
fi

# Define instructions for GPT
INSTRUCTIONS="Based on the description below, please generate a JSON object where the keys represent file paths and the values are the corresponding code snippets for a production-ready application. The response should be a valid strictly JSON object without any additional formatting, markdown, or characters outside the JSON structure."

# Combine instructions and issue body to form the full prompt
FULL_PROMPT="$INSTRUCTIONS\n\n$ISSUE_BODY"

# Prepare the JSON payload for the ChatGPT API
MESSAGES_JSON=$(jq -n --arg body "$FULL_PROMPT" '[{"role": "user", "content": $body}]')
PAYLOAD=$(jq -n --argjson messages "$MESSAGES_JSON" --arg model "gpt-3.5-turbo" --arg max_tokens 500 \
    '{"model": $model, "messages": $messages, "max_tokens": ($max_tokens | tonumber)}')

# Send the prompt to the ChatGPT model
CHATGPT_RESPONSE=$(send_prompt_to_chatgpt "$PAYLOAD")

if [[ -z "$CHATGPT_RESPONSE" ]]; then
    echo "No response received from the OpenAI API."
    exit 1
fi

# Extract the JSON dictionary from the response
FILES_JSON=$(echo "$CHATGPT_RESPONSE" | jq -e '.choices[0].message.content | fromjson' 2> /dev/null)

if [[ -z "$FILES_JSON" ]]; then
    echo "No valid JSON dictionary found in the response or the response was not valid JSON. Please rerun the job."
    exit 1
fi

# Iterate over each key-value pair in the JSON dictionary
for key in $(echo "$FILES_JSON" | jq -r 'keys[]'); do
    FILENAME=$key
    CODE_SNIPPET=$(echo "$FILES_JSON" | jq -r --arg key "$key" '.[$key]')
    CODE_SNIPPET=$(echo "$CODE_SNIPPET" | sed 's/\r$//') # Normalize line endings
    save_to_file "$FILENAME" "$CODE_SNIPPET"
done

echo "All files have been processed successfully."
