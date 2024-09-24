#!/bin/bash

# Check if the input folder is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <input_folder>"
    exit 1
fi

# Set the input folder
input_folder="$1"

# Loop through all .fna files in the input folder
for file in "$input_folder"/*.fna; do
    # Extract the first header
    grep "^>" "$file" | head -n 1 > "${file%.fna}_combined.fna"
    
    # Combine all sequences into a single line and append to the new file
    grep -v "^>" "$file" | tr -d '\n' >> "${file%.fna}_combined.fna"
done

echo "Contigs combined successfully in folder: $input_folder"