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
INSTRUCTIONS="Based on the description below, please provide the code for each file. " \
"List the filename followed by the corresponding code snippet enclosed in triple backticks."

# Combine the instructions with the issue body to form the full prompt
FULL_PROMPT="$INSTRUCTIONS\n\n$ISSUE_BODY"

# Prepare the messages array for the ChatGPT API, including the instructions
MESSAGES_JSON=$(jq -n --arg body "$FULL_PROMPT" '[{"role": "user", "content": $body}]')

# Send the prompt to the ChatGPT model (OpenAI API)
RESPONSE=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"gpt-3.5-turbo\", \"messages\": $MESSAGES_JSON, \"max_tokens\": 1024}")

# Check if the API call was successful
if [ $? -ne 0 ]; then
    echo "Failed to get a response from OpenAI API."
    exit 1
fi

# Extract the content from the assistant's message
CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')

# Regex pattern to match file names and code blocks
FILE_PATTERN='\d+\.\s+([a-zA-Z0-9._-]+)\s+\`\`\`[a-zA-Z]+\s+(.*?)\`\`\`'

# Process each matched file and code block
while [[ $CONTENT =~ $FILE_PATTERN ]]; do
    FILENAME="${BASH_REMATCH[1]}"
    CODE_SNIPPET="${BASH_REMATCH[2]}"

    # Check if the filename contains a valid extension
    if [[ "$FILENAME" =~ \. ]]; then
        # Save the generated content to the file
        echo "$CODE_SNIPPET" > "$FILENAME"
        echo "The code has been written to $FILENAME"
    else
        echo "Invalid filename ($FILENAME) found in the response."
        exit 1
    fi

    # Remove the processed file and code snippet from the content
    CONTENT=$(echo "$CONTENT" | sed "0,/$FILE_PATTERN/s///")
done

# If no files were processed, exit with an error
if ! [[ $CONTENT =~ $FILE_PATTERN ]]; then
    echo "No valid filenames and code blocks found in the response."
    exit 1
fi
