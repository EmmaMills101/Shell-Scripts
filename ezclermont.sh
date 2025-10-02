#!/bin/bash

# Help menu
usage() {
  echo "Usage: $0 -i <input_directory> -o <output_file>"
  echo "  -i    Directory containing .fasta/.fna/.fa files"
  echo "  -o    Output .tsv file name (Excel-compatible)"
  exit 1
}

# Parse input arguments
while getopts ":i:o:" opt; do
  case $opt in
    i) input_dir="$OPTARG" ;;
    o) output_file="$OPTARG" ;;
    *) usage ;;
  esac
done

# Check if required args are provided
if [ -z "$input_dir" ] || [ -z "$output_file" ]; then
  usage
fi

# Create output file and write header
echo -e "Sample\tClermont_Type" > "$output_file"

# Loop through fasta files
for file in "$input_dir"/*.{fasta,fna,fa}; do
  [ -e "$file" ] || continue  # Skip if no files match

  # Extract filename without path
  sample_name=$(basename "$file")
  
  # Run ezclermont and parse output
  result=$(ezclermont "$file" 2>/dev/null)
  
  # Append to output file
  echo -e "${sample_name}\t${result}" >> "$output_file"
done

echo "EZClermont completed. Results saved to: $output_file"

