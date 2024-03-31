##!/bin/bash
#
## Get inputs from the environment
#GITHUB_TOKEN="$1"
#REPOSITORY="$2"
#ISSUE_NUMBER="$3"
#OPENAI_API_KEY="$4"
#
## Get the issue labels using the GitHub API
#LABELS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
#"https://api.github.com/repos/$REPOSITORY/issues/$ISSUE_NUMBER/labels")
#
## Check if the issue has the autocoder-bot label
#if echo "$LABELS" | jq -e '.[] | select(.name == "autocoder-bot")' > /dev/null; then
#    # Get the issue body
#    ISSUE_BODY=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
#    "https://api.github.com/repos/$REPOSITORY/issues/$ISSUE_NUMBER" | jq -r .body)
#
#    # Prepare the messages array for the ChatGPT API
#    MESSAGES_JSON=$(jq -n --arg body "$ISSUE_BODY" '[{"role": "user", "content": $body}]')
#
#    # Send the issue content to the ChatGPT model (OpenAI API)
#    RESPONSE=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
#        -H "Authorization: Bearer $OPENAI_API_KEY" \
#        -H "Content-Type: application/json" \
#        -d "{\"model\": \"gpt-3.5-turbo\", \"messages\": $MESSAGES_JSON, \"max_tokens\": 400}")
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
#   echo "Code from ChatGPT: $CODE"
#
#
#    # Create a new branch
#    git checkout -b autocoder-branch
#
#    # Create the code file
#    echo "$CODE" > "$FILENAME"
#
#    # Add the new file to the staging area
#    git add "$FILENAME"
#
#    # Commit the new file
#    git -c user.name='autocoder-bot' -c user.email='autocoder-bot@example.com' \
#    commit -m "Add code snippets to issue #$ISSUE_NUMBER"
#
#    # Push the new branch to the remote repository
#    git push origin autocoder-branch
#fi

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
        -d "{\"model\": \"gpt-3.5-turbo\", \"messages\": $MESSAGES_JSON, \"max_tokens\": 400}")

    # Extract the content from the assistant's message
    CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')

    # Splitting the CONTENT into an array of code snippets
    IFS=$'\n' read -d '' -r -a snippets <<< "$CONTENT"

    # Loop through the snippets and save them to files
    for snippet in "${snippets[@]}"; do
        # Use a regex to extract the filename which is expected to follow the pattern "X. filename.ext"
        if [[ $snippet =~ ^([0-9]+)\.\ ([^\ ]+\.[^\ ]+) ]]; then
            FILENAME=${BASH_REMATCH[2]}
            # Remove the first line (which contains the filename) from the snippet
            CODE=$(echo "$snippet" | sed '1d')
            # Save the code to a file
            echo "$CODE" > "$FILENAME"
        fi
    done
fi
