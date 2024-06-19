#!/bin/bash

# Set the input and output directories
input_dir="./assemblies"
output_dir="./prokka"

# Create the output directory if it doesn't exist
mkdir -p "$output_dir"

# Iterate through all Fasta files in the input directory
for fasta_file in "$input_dir"/*.fasta; do
    # Extract the file name without the path and extension
    base_name=$(basename "$fasta_file" .fasta)

    # Run the prokka command for each Fasta file
    prokka "$fasta_file" \
        --outdir "$output_dir/$base_name" \
        --prefix "$base_name" \
        --locustag "$base_name"
done