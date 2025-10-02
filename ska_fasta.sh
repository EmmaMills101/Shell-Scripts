#!/bin/bash

# Default values
INPUT_DIR=""
OUTPUT_DIR=""

# Help message
usage() {
  echo "Usage: $0 -i /path/to/input_folder -o /path/to/output_folder"
  echo ""
  echo "  -i    Path to folder containing input .fasta/.fna/.fa files"
  echo "  -o    Path to output folder where .skf files will be stored"
  echo "  -h    Show this help message"
  exit 1
}

# Parse flags
while getopts ":i:o:h" opt; do
  case $opt in
    i) INPUT_DIR="$OPTARG" ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    h) usage ;;
    \?) echo "Invalid option -$OPTARG" >&2; usage ;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
  esac
done

# Check if both flags were provided
if [[ -z "$INPUT_DIR" || -z "$OUTPUT_DIR" ]]; then
  echo "Error: Both -i and -o options are required."
  usage
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Loop through valid fasta formats
shopt -s nullglob
for file in "$INPUT_DIR"/*.{fasta,fna,fa}; do
  # Get base name before first dot
  base=$(basename "$file")
  name="${base%%.*}"

  echo "Processing $file → $OUTPUT_DIR/$name.skf"

  ska fasta "$file" -o "$OUTPUT_DIR/$name"
done
shopt -u nullglob

echo "SKA processing complete. Output files in $OUTPUT_DIR/"

