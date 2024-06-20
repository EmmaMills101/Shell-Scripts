#!/bin/bash

# Check if the input folder is provided
if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/input_folder"
    exit 1
fi

# Get the input folder from the first positional argument
input_folder=$1

# Loop through all .fasta files in the input folder
for assembly in "$input_folder"/*.fasta; do
    # Get the base of the filename
    base=$(basename "$assembly" .fasta)
    # Run amrfinder with output going to the base.amrfinder
    amrfinder -n "$assembly" --threads 6 --plus -O Enterococcus_faecium > "$input_folder/$base.amrfinder"
done

# Get one copy of the header
head -1 $(ls "$input_folder"/*.amrfinder | head -1) > "$input_folder/combined.tsv"
# Skip headers and concatenate all files ending in .amrfinder
grep -h -v 'Protein identifier' "$input_folder"/*.amrfinder >> "$input_folder/combined.tsv"
