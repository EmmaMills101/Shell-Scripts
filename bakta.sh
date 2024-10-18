#!/bin/bash

# Function to display help menu
show_help() {
    echo "Usage: $0 -i INPUT_DIR -o OUTPUT_DIR -d DB_PATH"
    echo ""
    echo "Run Bakta on all .fasta and .fna files in the specified input directory."
    echo ""
    echo "Options:"
    echo "  -i    Path to the input directory containing .fasta and .fna files"
    echo "  -o    Path to the output directory where Bakta results will be saved"
    echo "  -d    Path to the Bakta database"
    echo "  -h    Display this help message"
    echo ""
}

# Parse command line options
while getopts ":i:o:d:h" opt; do
    case ${opt} in
        i )
            INPUT_DIR=$OPTARG
            ;;
        o )
            OUTPUT_DIR=$OPTARG
            ;;
        d )
            DB_PATH=$OPTARG
            ;;
        h )
            show_help
            exit 0
            ;;
        \? )
            echo "Invalid option: -$OPTARG" 1>&2
            show_help
            exit 1
            ;;
        : )
            echo "Option -$OPTARG requires an argument." 1>&2
            show_help
            exit 1
            ;;
    esac
done

# Check if required arguments are provided
if [ -z "$INPUT_DIR" ] || [ -z "$OUTPUT_DIR" ] || [ -z "$DB_PATH" ]; then
    echo "Error: Missing required arguments." 1>&2
    show_help
    exit 1
fi

# Check if input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory does not exist." 1>&2
    exit 1
fi

# Check if output directory exists, if not create it
if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
fi

# Loop over .fasta and .fna files in the input directory
for file in "$INPUT_DIR"/*.{fasta,fna}; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        prefix="${filename%.*}"
        
        # Run Bakta command
        bakta --db "$DB_PATH" \
              --output "$OUTPUT_DIR/$prefix" \
              --prefix "$prefix" \
              --locus-tag "$prefix" \
              --threads 8 \
              "$file"
    fi
done

echo "Bakta is complete - NICE!"
