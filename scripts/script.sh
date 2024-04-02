#!/bin/bash

# Get inputs from the environment
GITHUB_TOKEN="$1"
REPOSITORY="$2"
ISSUE_NUMBER="$3"
OPENAI_API_KEY="$4"

# Fetch issue details from GitHub API
RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
"https://api.github.com/repos/$REPOSITORY/issues/$ISSUE_NUMBER")

# Check if the response contains an issue body
ISSUE_BODY=$(echo "$RESPONSE" | jq -r .body)
echo "Issue body: $ISSUE_BODY"

if [[ -z "$ISSUE_BODY" ]]; then
    echo 'Issue body is empty or not found in the response.'
    exit 1
fi

# Define clear, concise instructions for GPT
INSTRUCTIONS="Based on the description below, please list the files and code for a production ready application. Provide the information as a compact, JSON-formatted dictionary where the keys are file paths (not directories, just files!) and the values are the code. Stick to that description, don't add anything else. Make the minimum amount of assumptions about the rest of the repo. \n"

# Combine the instructions with the issue body to form the full prompt
FULL_PROMPT="$INSTRUCTIONS\n\n$ISSUE_BODY"

# Prepare the messages array for the ChatGPT API, including the instructions
MESSAGES_JSON=$(jq -n --arg body "$FULL_PROMPT" '[{"role": "user", "content": $body}]')

# Send the prompt to the ChatGPT model (OpenAI API)
RESPONSE=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"gpt-3.5-turbo\", \"messages\": $MESSAGES_JSON, \"max_tokens\": 300}")
check_status 'Failed to get a response from OpenAI API.'

# Extract the content from the assistant's message and output as a JSON dictionary
FILES_JSON=$(echo "$RESPONSE" | jq -r '.choices[0].message.content | fromjson')

# Check if we have a valid JSON dictionary
if [[ -z "$FILES_JSON" ]]; then
    echo "No valid JSON dictionary found in the response."
    exit 1
fi

# Iterate over each key-value pair in the JSON dictionary
for key in $(echo "$FILES_JSON" | jq -r 'keys[]'); do
    # Extract the filename and code snippet
    FILENAME=$key
    CODE_SNIPPET=$(echo "$FILES_JSON" | jq -r --arg key "$key" '.[$key]')

    # Normalize the end of lines from Windows to Unix if needed
    CODE_SNIPPET=$(echo "$CODE_SNIPPET" | sed 's/\r$//')

    # Ensure the directory exists
    mkdir -p "$(dirname "$FILENAME")"

    # Save the generated content to the file
    echo -e "$CODE_SNIPPET" > "$FILENAME"
    echo "The code has been written to $FILENAME"
done

# Check if at least one file was processed
if [ -z "$FILENAME" ]; then
    echo "No files were written."
    exit 1
fi