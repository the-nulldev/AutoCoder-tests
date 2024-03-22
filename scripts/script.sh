##!/bin/bash
#
## Get the issue labels using the GitHub API
#LABELS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
#"https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER/labels")
#
## Check if the API response is valid JSON
#if ! echo "$LABELS" | jq empty; then
#    echo "Error: Invalid API response"
#    exit 1
#fi
#
## Check if the issue has the autocoder-bot label
#if echo "$LABELS" | jq -e '.[] | select(.name == "autocoder-bot")' > /dev/null; then
#    # get issue body
#    ISSUE_BODY=$(curl -s -H "Authorization : token $GITHUB_TOKEN" \
#    "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUMBER" | jq -r '.body')
#
#    # Prepare the messages array for the ChatGPT API
#    MESSAGES_JSON=$(jq -n --arg body "$ISSUE_BODY" '[{"role": "user", "content": $body}]')
#
#    # Send the issue content to the ChatGPT model (OpenAI API)
#    RESPONSE=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
#        -H "Authorization: Bearer $OPENAI_API_KEY" \
#        -H "Content-Type: application/json" \
#        -d "{\"model\": \"gpt-3.5-turbo\", \"messages\": $MESSAGES_JSON, \"max_tokens\": 4096}")
#
#    # Extract the content from the assistant's message
#    CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')
#
#    # Use a regex to extract the filename which is expected to follow the pattern "# File name: filename.ext"
#    FILENAME=$(echo "$CONTENT" | grep -oP '(?<=# File name: ).*')
#
#    # Extract the code, removing the first line that contains the filename
#    CODE=$(echo "$CONTENT" | sed '1d')
#
#    # return the file name and the code to the GitHub Actions worflow as an output
#    echo "::set-output name=filename::$FILENAME"
#    echo "::set-output name=code::$CODE"
#
#fi

#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# GitHub repository and issue number are provided as arguments
REPO=$1
ISSUE_NUMBER=$2
PERSONAL_ACCESS_TOKEN=$3
OPENAI_API_KEY=$4

# Fetch issue description from GitHub API
echo "Fetching issue description from GitHub..."
ISSUE_DESCRIPTION=$(curl -s -H "Authorization: token $PERSONAL_ACCESS_TOKEN" \
"https://api.github.com/repos/$REPO/issues/$ISSUE_NUMBER" | jq -r .body)

# Prepare the prompt for OpenAI API
MESSAGES_JSON=$(jq -n --arg content "$ISSUE_DESCRIPTION" '[{"role": "system", "content": "You are a helpful assistant."}, {"role": "user", "content": $content}]')
#
## Send the issue content to the ChatGPT model (OpenAI API)
#echo "Generating file contents using OpenAI..."
#RESPONSE=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
#    -H "Authorization: Bearer $OPENAI_API_KEY" \
#    -H "Content-Type: application/json" \
#    -d "{\"model\": \"gpt-3.5-turbo\", \"messages\": $MESSAGES_JSON, \"max_tokens\": 200}")

# Call OpenAI API to generate file contents
echo "Generating file contents using OpenAI..."
GENERATED_CONTENT=$(curl -s -X POST "https://api.openai.com/v1/engines/davinci-codex/completions" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"prompt\": \"${ISSUE_DESCRIPTION}\", \"max_tokens\": 300, \"stop\": \"###\"}")

# Parse the generated content into files and directories
echo "Parsing generated content..."
echo "$GENERATED_CONTENT" | while read -r line; do
    # Expecting lines to be in format: "path/to/file: file content"
    FILE_PATH=$(echo $line | cut -d':' -f1)
    CONTENT=$(echo $line | cut -d':' -f2-)
    DIR_PATH=$(dirname "$FILE_PATH")

    # Create directory if it doesn't exist
    if [ ! -d "$DIR_PATH" ]; then
        mkdir -p "$DIR_PATH"
    fi

    # Write content to file
    echo -e "$CONTENT" > "$FILE_PATH"
done

# add configs
git config --global user.name "runner"
git config --global user.email "runner@example.com"

# Create a new branch
BRANCH_NAME="autocoder-branch"
git checkout -b "$BRANCH_NAME"

# Add and commit changes
git add .
git commit -m "Auto-generated files from issue #$ISSUE_NUMBER"

# Push the branch to the remote
git push origin "$BRANCH_NAME"

# Open a pull request
echo "Opening a pull request..."
PR_RESPONSE=$(curl -s -X POST -H "Authorization: token $PERSONAL_ACCESS_TOKEN" \
    -d "{\"title\": \"Auto-generated files for issue #$ISSUE_NUMBER\", \"head\": \"$BRANCH_NAME\", \"base\": \"main\"}" \
    "https://api.github.com/repos/$REPO/pulls")

echo "Pull request created: $(echo "$PR_RESPONSE" | jq -r '.html_url')"