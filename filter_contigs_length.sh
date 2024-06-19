#!/bin/bash

# Activate bbmap
source activate bbmap

# Define the minimum length
min_length=200

# Specify the directory containing your input FASTA files
input_directory="./Emma_Assemblies"

# Specify the directory where you want to save the filtered FASTA files
output_directory="./200_filtered"

# Iterate over the input files
for input_file in "$input_directory"/*.fna; do
    # Get the filename without the path and extension
    filename=$(basename -- "$input_file")
    filename_no_ext="${filename%.*}"

    # Define the output file path
    output_file="$output_directory/${filename_no_ext}_filtered.fna"

    # Use reformat.sh to filter contigs
    reformat.sh in="$input_file" out="$output_file" minlength="$min_length"

    echo "Filtered $input_file and saved to $output_file"
done

# Deactivate bbmap
conda deactivate
