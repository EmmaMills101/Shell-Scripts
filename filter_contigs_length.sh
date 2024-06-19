#!/bin/bash

# Check if the input directory is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/input"
    exit 1
fi

# Set the input directory from the argument
input_directory="$1"

# Define the minimum length
min_length=200

# Specify the directory where you want to save the filtered FASTA files
output_directory="./200_filtered"

# Create the output directory if it doesn't exist
mkdir -p "$output_directory"

# Activate bbmap
source activate bbmap

# Iterate over the input files
for input_file in "$input_directory"/*.fasta; do
    # Get the filename without the path and extension
    filename=$(basename -- "$input_file")
    filename_no_ext="${filename%.*}"

    # Define the output file path
    output_file="$output_directory/${filename_no_ext}_filtered.fasta"

    # Use reformat.sh to filter contigs
    reformat.sh in="$input_file" out="$output_file" minlength="$min_length"

    echo "Filtered $input_file and saved to $output_file"
done

# Deactivate bbmap
conda deactivate
