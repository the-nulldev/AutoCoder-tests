#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# log each command
set -x

# Get inputs from the environment
GITHUB_TOKEN="$1"
REPOSITORY="$2"
ISSUE_NUMBER="$3"

# Function to fetch issue details from GitHub API
fetch_issue_details() {
    curl -s -H "Authorization: token $GITHUB_TOKEN" \
         "https://api.github.com/repos/$REPOSITORY/issues/$ISSUE_NUMBER"
}

# Function to save code snippet to file
save_to_file() {
    local filename="autocoder-bot/$1"
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

# Define clear, additional instructions for GPT regarding the response format
INSTRUCTIONS="Based on the description below, please generate a JSON object where the keys represent file paths and the values are the corresponding code snippets for a production-ready application. The response should be a valid strictly JSON object without any additional formatting, markdown, or characters outside the JSON structure."

# Combine the instructions with the issue body to form the full prompt
FULL_PROMPT="$INSTRUCTIONS\n\n$ISSUE_BODY"

# Create a Python script to send the prompt to the ChatGPT model
python -c "
import os
import openai
import json
openai.api_base='https://mockgpt.wiremockapi.cloud/v1'
openai.api_key='sk-uqywzmvjwodqq4agnqepmsjiytbzwqv'
chat_completion = openai.ChatCompletion.create(model='gpt-3.5-turbo', messages=[{'role': 'user', 'content': '$FULL_PROMPT'}])
response = chat_completion.choices[0].message.content
print(json.loads(response))
" > response.json

# Extract the JSON dictionary from the response
FILES_JSON=$(jq -r '.[]' response.json)

# Iterate over each key-value pair in the JSON dictionary
for key in $(echo "$FILES_JSON" | jq -r 'keys[]'); do
    FILENAME=$key
    CODE_SNIPPET=$(echo "$FILES_JSON" | jq -r --arg key "$key" '.[$key]')
    CODE_SNIPPET=$(echo "$CODE_SNIPPET" | sed 's/\r$//') # Normalize line endings
    save_to_file "$FILENAME" "$CODE_SNIPPET"
done

echo "All files have been processed successfully."

# Requirements
python -c "
import os
import openai
import json
openai.api_base='https://mockgpt.wiremockapi.cloud/v1'
openai.api_key='sk-uqywzmvjwodqq4agnqepmsjiytbzwqv'
chat_completion = openai.ChatCompletion.create(model='gpt-3.5-turbo', messages=[{'role': 'user', 'content': 'Please provide the requirements for the project.'}])
response = chat_completion.choices[0].message.content
print(json.loads(response))
" > requirements.json

# Extract the requirements from the response
REQUIREMENTS=$(jq -r '.[]' requirements.json)

# Print the requirements
echo "Requirements:"
echo "$REQUIREMENTS"
