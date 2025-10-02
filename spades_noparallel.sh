#!/bin/bash

# Usage: bash spades.sh -i <input path> -o <output path>
# Runs SPAdes for paired-end reads and writes final FASTA
# as <SAMPLE>.fasta where SAMPLE is the part before the first underscore
# in the input R1 filename. Contigs <200 bp are removed and headers set to SAMPLE_1, SAMPLE_2, ...

show_help() {
    echo "Usage: bash spades.sh -i <input path> -o <output path>"
    echo "Options:"
    echo "  -i <input path>   Directory containing input FASTQ files."
    echo "  -o <output path>  Directory to store final FASTA files."
    echo "  -h                Display this help message."
    echo
    echo "Supported paired-end naming:"
    echo "  *_R1.fastq.gz     ↔ *_R2.fastq.gz"
    echo "  *_R1_001.fastq.gz ↔ *_R2_001.fastq.gz"
    echo "  *_R1.fastq        ↔ *_R2.fastq"
    echo "  *_R1_001.fastq    ↔ *_R2_001.fastq"
    echo "  *_1.fastq.gz      ↔ *_2.fastq.gz"
    echo "  *_1.fastq         ↔ *_2.fastq"
    exit 0
}

# Parse arguments
while getopts "i:o:h" opt; do
    case $opt in
        i) INPUT_DIR="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        h) show_help ;;
        *) echo "Invalid option. Use -h for help."; exit 1 ;;
    esac
done

# Validate arguments
if [ -z "$INPUT_DIR" ]; then echo "Missing -i"; exit 1; fi
if [ -z "$OUTPUT_DIR" ]; then echo "Missing -o"; exit 1; fi
if [ ! -d "$INPUT_DIR" ]; then echo "Directory $INPUT_DIR not found."; exit 1; fi

mkdir -p "$OUTPUT_DIR"

# Resources
THREADS=6
MEMORY=12
MAX_PARALLEL_JOBS=$((32 / THREADS))  # unused in sequential mode

# Rename + filter contigs >=200bp, headers as SAMPLE_1, SAMPLE_2, ...
clean_fasta_ids() {
    local fasta_file="$1"
    local sample="$2"
    local tmp="${fasta_file}.tmp"

    awk -v sample="$sample" 'BEGIN {id=1; seq=""}
        /^>/ {
            if (seq != "" && length(seq) >= 200) {
                print header "\n" seq
                id++
            }
            header=">" sample "_" id
            seq=""
            next
        }
        { seq = seq $0 }
        END {
            if (length(seq) >= 200) {
                print header "\n" seq
            }
        }' "$fasta_file" > "$tmp"

    mv "$tmp" "$fasta_file"
}

# Run SPAdes on one sample (argument is basename of R1 file)
run_spades() {
    local r1_file="$1"    # basename only
    local r2_file=""
    local stem=""         # stem without _R1/_1 suffix
    local outdir=""

    # Determine matching R2 and stem based on pattern + compression
    if [[ "$r1_file" == *_R1_001.fastq.gz ]]; then
        r2_file="${r1_file/_R1_001.fastq.gz/_R2_001.fastq.gz}"
        stem="${r1_file%%_R1_001.fastq.gz}"
    elif [[ "$r1_file" == *_R1.fastq.gz ]]; then
        r2_file="${r1_file/_R1.fastq.gz/_R2.fastq.gz}"
        stem="${r1_file%%_R1.fastq.gz}"
    elif [[ "$r1_file" == *_R1_001.fastq ]]; then
        r2_file="${r1_file/_R1_001.fastq/_R2_001.fastq}"
        stem="${r1_file%%_R1_001.fastq}"
    elif [[ "$r1_file" == *_R1.fastq ]]; then
        r2_file="${r1_file/_R1.fastq/_R2.fastq}"
        stem="${r1_file%%_R1.fastq}"
    elif [[ "$r1_file" == *_1.fastq.gz ]]; then
        r2_file="${r1_file/_1.fastq.gz/_2.fastq.gz}"
        stem="${r1_file%%_1.fastq.gz}"
    elif [[ "$r1_file" == *_1.fastq ]]; then
        r2_file="${r1_file/_1.fastq/_2.fastq}"
        stem="${r1_file%%_1.fastq}"
    else
        echo "Skipping $(basename "$r1_file"): unsupported R1 pattern."
        return
    fi

    if [ ! -f "$INPUT_DIR/$r2_file" ]; then
        echo "⚠️  Skipping $(basename "$r1_file"): matching R2 not found."
        return
    fi

    # SAMPLE = everything before the first underscore of the stem
    local sample="${stem%%_*}"

    # SPAdes working directory keeps the full stem (avoid collisions)
    outdir="$INPUT_DIR/${stem}_spades"

    # Final output FASTA uses SAMPLE only
    local final_fa="$OUTPUT_DIR/${sample}.fasta"
    if [ -f "$final_fa" ]; then
        echo "Skipping $sample (final FASTA already exists: $final_fa)."
        return
    fi

    echo "Assembling $sample ..."

    spades.py --careful \
        -1 "$INPUT_DIR/$r1_file" \
        -2 "$INPUT_DIR/$r2_file" \
        -o "$outdir" -t "$THREADS" -m "$MEMORY"

    if [ -f "$outdir/contigs.fasta" ]; then
        cp "$outdir/contigs.fasta" "$final_fa"
        clean_fasta_ids "$final_fa" "$sample"
    else
        echo "Warning: contigs.fasta missing for $sample"
    fi
}

export -f run_spades
export -f clean_fasta_ids
export INPUT_DIR OUTPUT_DIR THREADS MEMORY

# Find all supported R1 reads and run sequentially (no parallel processing)
find "$INPUT_DIR" -type f \( \
    -name "*_R1.fastq.gz"   -o -name "*_R1_001.fastq.gz" -o \
    -name "*_R1.fastq"      -o -name "*_R1_001.fastq"    -o \
    -name "*_1.fastq.gz"    -o -name "*_1.fastq" \
\) -print0 | while IFS= read -r -d '' f; do
    run_spades "$(basename "$f")"
done

echo "All SPAdes jobs complete ✅  Check $OUTPUT_DIR for results."
