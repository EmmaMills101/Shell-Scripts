#!/bin/bash

# Check if the directory path is provided as an argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <directory_path>"
    exit 1
fi

# Directory path provided as the first argument
directory="$1"

# Check if the provided path is a valid directory
if [ ! -d "$directory" ]; then
    echo "Error: $directory is not a valid directory."
    exit 1
fi

# Process each .fna file in the directory and its subdirectories
find "$directory" -type f -name "*.fna" | while IFS= read -r file; do
    # Create a temporary file to store modified content
    temp_file=$(mktemp)
    # For each file, replace spaces with underscores in lines starting with ">"
    sed '/^>/ s/ /_/g' "$file" > "$temp_file"
    # Replace the original file with the modified one
    mv "$temp_file" "$file"
done