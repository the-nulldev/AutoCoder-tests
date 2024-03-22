#!/bin/bash

# Set up error handling
set -Eeuo pipefail

# Function to handle errors
error_handling() {
  echo "Error on line $1"
  exit 1
}
trap 'error_handling $LINENO' ERR

# Get inputs from the environment
GITHUB_TOKEN="$1"
REPOSITORY="$2"
ISSUE_NUMBER="$3"
OPENAI_API_KEY="$4"
MODEL_NAME="${5:-gpt-3.5-turbo}"
MAX_TOKENS="${6:-300}"

# Define the GitHub issue URL
GITHUB_ISSUE_URL="https://api.github.com/repos/${REPOSITORY}/issues/${ISSUE_NUMBER}"

# Ensure all required parameters are provided
if [ -z "${GITHUB_TOKEN}" ] || [ -z "${REPOSITORY}" ] || [ -z "${ISSUE_NUMBER}" ] || [ -z "${OPENAI_API_KEY}" ]; then
  echo "Usage: $0 GITHUB_TOKEN REPOSITORY ISSUE_NUMBER OPENAI_API_KEY [MODEL_NAME] [MAX_TOKENS]"
  exit 1
fi

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq could not be found. Please install jq to run this script."
    exit 1
fi

# Function to ensure directory exists
ensure_directory() {
    directory=$(dirname "$1")
    if [[ ! -d "${directory}" ]]; then
        mkdir -p "${directory}"
        echo "Ensured directory for $1."
    fi
}

# Function to validate JSON output
validate_dict_output() {
    echo "Validating dict: $1"
    parsed_output=$(echo "$1" | jq -r 'if type=="object" then . else empty end')
    if [[ -z "${parsed_output}" ]]; then
        echo "Output is not a dictionary."
        return 1
    fi
    echo "Validation passed."
    echo "${parsed_output}"
    return 0
}

# Function to make an OpenAI API call
openai_call() {
    prompt="$1"
    model_name="$2"
    max_tokens="$3"
    response=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${OPENAI_API_KEY}" \
        -d "{
            \"model\": \"${model_name}\",
            \"messages\": [
                {\"role\": \"system\", \"content\": \"You are a script that helps set up a Repository with initial files.\"},
                {\"role\": \"user\", \"content\": \"${prompt}\"}
            ],
            \"max_tokens\": ${max_tokens}
        }")
    if [ $? -ne 0 ]; then
        echo "Failed to make OpenAI API call"
        exit 1
    fi
    echo "${response}" | jq -r '.choices[0].message.content | rtrimstr("\n")'
}

# Get the prompt from GitHub issue
prompt=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" "${GITHUB_ISSUE_URL}" | jq -r '.body')
if [ $? -ne 0 ]; then
    echo "Failed to fetch GitHub issue"
    exit 1
fi

# Get file requirements
raw_output=$(openai_call "${prompt}" "${MODEL_NAME}" "${MAX_TOKENS}")
files_and_requirements=$(validate_dict_output "${raw_output}")
if [[ $? -ne 0 ]]; then
    echo "Invalid file requirements dictionary. Exiting."
    exit 1
fi

# Function to get file content
get_file_content() {
    file_path="$1"
    file_descriptions="$2"
    files_and_requirements="$3"
    model_name="$4"
    max_tokens="$5"

    # Use the file descriptions as a prompt for the OpenAI API to generate the file content
    file_content=$(openai_call "${file_descriptions}" "${model_name}" "${max_tokens}")
    if [ $? -ne 0 ]; then
        echo "Failed to generate content for ${file_path}"
        exit 1
    fi

    echo "${file_content}"
}

# Iterate over files and create content
echo "${files_and_requirements}" | jq -r 'to_entries | .[] | @base64' | while read -r line; do
    _jq() {
        echo "${line}" | base64 --decode | jq -r "${1}"
    }

    file_path=$(_jq '.key')
    file_descriptions=$(_jq '.value')

    if [[ "${file_path}" == *".github"* ]]; then
        echo "Replacing .github in ${file_path}"
        file_path=$(echo "${file_path}" | sed 's/\.github/github/g')
    fi

    if [[ -f "${file_path}" ]]; then
        echo "File ${file_path} already exists. Skipping."
        continue
    fi

    ensure_directory "${file_path}"
    file_content=$(get_file_content "${file_path}" "${file_descriptions}" "${files_and_requirements}" "${MODEL_NAME}" "${MAX_TOKENS}")

    echo "Writing to: ${file_path}"
    echo "${file_content}" > "${file_path}"
    if [ $? -ne 0 ]; then
        echo "Failed to write to ${file_path}"
        exit 1
    fi
done

exit 0