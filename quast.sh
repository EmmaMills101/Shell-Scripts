#!/bin/bash

# Help message
usage() {
  echo "Usage: $0 -i <input_dir> -o <output_dir> -f <output_excel_filename.xlsx>"
  exit 1
}

# Parse arguments
while getopts "i:o:f:" opt; do
  case "$opt" in
    i) INPUT_DIR="$OPTARG" ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    f) OUT_XLSX="$OPTARG" ;;
    *) usage ;;
  esac
done

# Validate input
if [[ -z "$INPUT_DIR" || -z "$OUTPUT_DIR" || -z "$OUT_XLSX" ]]; then
  usage
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Run Quast on each assembly
shopt -s nullglob
for asm in "$INPUT_DIR"/*.{fa,fna,fasta}; do
  base=$(basename "$asm")
  sample=${base%%.*}
  outdir="$OUTPUT_DIR/$sample"
  if [[ ! -d "$outdir" ]]; then
    echo "🔍 Running Quast on $base..."
    quast "$asm" -o "$outdir"
  else
    echo "⚠️ Skipping $base — output already exists at $outdir"
  fi
done
shopt -u nullglob

# Combined summary TSV file (temporary)
OUT_TSV="${OUT_XLSX%.xlsx}.tsv"

# Metrics to extract
METRICS=(
"# contigs (>= 0 bp)"
"# contigs (>= 1000 bp)"
"# contigs (>= 5000 bp)"
"# contigs (>= 10000 bp)"
"# contigs (>= 25000 bp)"
"# contigs (>= 50000 bp)"
"Total length (>= 0 bp)"
"Total length (>= 1000 bp)"
"Total length (>= 5000 bp)"
"Total length (>= 10000 bp)"
"Total length (>= 25000 bp)"
"Total length (>= 50000 bp)"
"# contigs"
"Largest contig"
"Total length"
"GC (%)"
"N50"
"N90"
"auN"
"L50"
"L90"
"# N's per 100 kbp"
)

# Write header
{
  echo -ne "File"
  for metric in "${METRICS[@]}"; do
    echo -ne "\t$metric"
  done
  echo
} > "$OUT_TSV"

# Extract metrics
for rpt in "$OUTPUT_DIR"/*/report.tsv; do
  folder=$(basename "$(dirname "$rpt")")
  {
    echo -ne "$folder"
    for metric in "${METRICS[@]}"; do
      value=$(awk -F'\t' -v m="$metric" '$1 == m { print $2 }' "$rpt")
      echo -ne "\t$value"
    done
    echo
  } >> "$OUT_TSV"
done

# Convert TSV to Excel
python3 - <<EOF
import pandas as pd
df = pd.read_csv("$OUT_TSV", sep="\t")
df.to_excel("$OUT_XLSX", index=False)
EOF

echo "✅ Quast analysis and summary complete. Excel saved to: $OUT_XLSX"

