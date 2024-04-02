# Check if we have a valid JSON dictionary
if [[ -z "$FILES_JSON" ]]; then
    echo "No valid JSON dictionary found in the response."
    exit 1
fi

# Check if the JSON dictionary contains only one key-value pair
if [ $(echo "$FILES_JSON" | jq 'length') -eq 1 ]; then
    # Extract the filename and code snippet
    FILENAME=$(echo "$FILES_JSON" | jq -r 'keys[0]')
    CODE_SNIPPET=$(echo "$FILES_JSON" | jq -r '.[0]')

    # Normalize the end of lines from Windows to Unix if needed
    CODE_SNIPPET=$(echo "$CODE_SNIPPET" | sed 's/\r$//')

    # Ensure the directory exists
    mkdir -p "$(dirname "$FILENAME")"

    # Save the generated content to the file
    echo -e "$CODE_SNIPPET" > "$FILENAME"
    echo "The code has been written to $FILENAME"
else
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
fi

# Check if at least one file was processed
if [ -z "$FILENAME" ]; then
    echo "No files were written."
    exit 1
fi