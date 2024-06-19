#!/bin/bash

# Check if folder path argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <folder_path>"
    exit 1
fi

# Get the folder path from command line argument
folder_path="$1"

# Check if folder path exists
if [ ! -d "$folder_path" ]; then
    echo "Error: Folder not found: $folder_path"
    exit 1
fi

# Loop through each .fasta file in the folder
for fasta_file in "$folder_path"/*.fasta; do
    # Get the file name without extension
    file_name=$(basename "$fasta_file" .fasta)

    # Process each line in the file
    while IFS= read -r line; do
        # If the line starts with '>', prefix it with the file name followed by an underscore
        if [[ $line == \>* ]]; then
            echo ">${file_name}_${line:1}"
        else
            echo "$line"
        fi
    done < "$fasta_file" > "${folder_path}/${file_name}_temp.fasta"

    # Replace the original file with the modified one
    mv "${folder_path}/${file_name}_temp.fasta" "$fasta_file"
done

echo "Operation completed successfully!"