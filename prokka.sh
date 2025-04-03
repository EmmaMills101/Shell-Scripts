#!/bin/bash

# Function to display help message
show_help() {
    echo "Usage: sh prokka.sh -i /path/to/input [-o /path/to/output]"
    echo ""
    echo "Options:"
    echo "  -i    Specify the input directory containing .fasta or .fna files."
    echo "  -o    Specify the output directory for prokka results. (default: ./prokka)"
    echo "  -h    Show this help message."
}

# Default output directory
output_dir="./prokka"

# Parse command-line options
while getopts ":i:o:h" opt; do
    case $opt in
        i) input_dir="$OPTARG" ;;
        o) output_dir="$OPTARG" ;;
        h) show_help; exit 0 ;;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
        :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
    esac
done

# Check if the input directory is provided
if [ -z "$input_dir" ]; then
    echo "Error: Input directory not specified."
    show_help
    exit 1
fi

# Create the output directory if it doesn't exist
mkdir -p "$output_dir"

# Iterate through all .fasta and .fna files in the input directory
for fasta_file in "$input_dir"/*.{fasta,fna}; do
    # Check if there are no matching files in the input directory
    if [ ! -e "$fasta_file" ]; then
        echo "No .fasta or .fna files found in the input directory."
        exit 1
    fi

    # Extract the file name without the path and extension
    base_name=$(basename "$fasta_file" .fasta)
    base_name=$(basename "$base_name" .fna)

    # Run the prokka command for each file
    prokka "$fasta_file" \
        --outdir "$output_dir/$base_name" \
        --prefix "$base_name" \
        --locustag "$base_name"
done

# Completion message
echo "Prokka annotation complete! Results are saved in $output_dir."
