#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 -i <input_directory> -o <output_file> [-O <species_name>]"
    exit 1
}

# Initialize variables
input_dir=""
output_file=""
species_option=""

# Process command-line arguments
while getopts ":i:o:O:" opt; do
    case $opt in
        i)
            input_dir="$OPTARG"
            ;;
        o)
            output_file="$OPTARG"
            ;;
        O)
            species_option="-O $OPTARG"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done

# Ensure input directory and output file are provided
if [ -z "$input_dir" ] || [ -z "$output_file" ]; then
    usage
fi

# Check if the input directory exists
if [ ! -d "$input_dir" ]; then
    echo "Error: Directory $input_dir does not exist."
    exit 1
fi

# Change to the input directory
cd "$input_dir"

# Check if there are any *.fna or *.fasta files in the directory
shopt -s nullglob
fasta_files=(*.fasta *.fna)
shopt -u nullglob

if [ ${#fasta_files[@]} -eq 0 ]; then
    echo "No *.fna or *.fasta files found in the directory."
    exit 1
fi

# Loop through all .fna and .fasta files and run AMRFinderPlus with or without the -O option
for assembly in "${fasta_files[@]}"
do
    # Get the base of the filename
    base=$(basename "$assembly" .fasta)
    base=$(basename "$base" .fna)
    
    # Run AMRFinder with or without the species option
    amrfinder -n "$assembly" --threads 6 $species_option > "${base}.amrfinder"
    
    # Add the filename as the first column in the AMRFinder output
    awk -v fname="$base" 'NR==1{print "Filename\t"$0} NR>1{print fname"\t"$0}' "${base}.amrfinder" > "${base}.amrfinder.tmp"
    
    # Replace the original output file with the new one containing the filename column
    mv "${base}.amrfinder.tmp" "${base}.amrfinder"
done

# Check if any .amrfinder files were generated
shopt -s nullglob
amrfinder_files=(*.amrfinder)
shopt -u nullglob

if [ ${#amrfinder_files[@]} -eq 0 ]; then
    echo "No .amrfinder files generated."
    exit 1
fi

# Get one copy of the header
head -1 "${amrfinder_files[0]}" > "$output_file"

# Skip headers and concatenate all files ending in .amrfinder
grep -h -v 'Protein identifier' *.amrfinder >> "$output_file"

echo "AMRFinder results have been combined into $output_file"
