#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -lt 6 ]; then
  echo "Usage: $0 -i <input_path> -o <output_path> --db <db_path>"
  exit 1
fi

# Initialize variables for paths
input_path=""
output_path=""
db_path=""

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -i) input_path="$2"; shift 2 ;;
    -o) output_path="$2"; shift 2 ;;
    --db) db_path="$2"; shift 2 ;;
    *) echo "Unknown parameter passed: $1"; exit 1 ;;
  esac
done

# Validate the input and output paths
if [ -z "$input_path" ] || [ -z "$output_path" ] || [ -z "$db_path" ]; then
  echo "Error: Missing required arguments. Ensure you provide -i, -o, and --db options."
  exit 1
fi

# Check if the input path exists and is a directory
if [ ! -d "$input_path" ]; then
  echo "Error: Input path '$input_path' does not exist or is not a directory."
  exit 1
fi

# Create the output directory if it doesn't exist
mkdir -p "$output_path"

# Check if there are any .fastq.gz files in the input path
shopt -s nullglob
files=("$input_path"/*.fastq.gz)
if [ ${#files[@]} -eq 0 ]; then
  echo "Error: No .fastq.gz files found in the input path."
  exit 1
fi

# Loop through all .fastq.gz files in the input path
for file in "${files[@]}"; do
  # Extract the first DVT#### pattern from the filename
  base_name=$(basename "$file" | grep -oE 'DVT[0-9]{4}' | head -n 1)

  # Check if a valid base name was found
  if [ -z "$base_name" ]; then
    echo "Warning: No valid DVT#### pattern found in filename '$file'. Skipping."
    continue
  fi

  # Run the tracs align command with the specified database and paths
  echo "Processing file: $file"
  yes y | tracs align -i "$file" -o "$output_path/$base_name" --prefix "$base_name" --keep-all -t 20 --database "$db_path"
done

echo "Processing completed."