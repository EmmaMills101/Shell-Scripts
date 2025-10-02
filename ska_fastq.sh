#!/bin/bash
set -euo pipefail

# Usage: ./ska_fastq.sh -i input_dir -o output_dir
INPUT_DIR=""
OUTPUT_DIR=""

show_help() {
  cat <<'HLP'
Usage:
  ./ska_fastq.sh -i INPUT_DIR -o OUTPUT_DIR

Required:
  -i   Directory containing FASTQ/FASTQ.GZ files
  -o   Output directory for SKA outputs (created if missing)

Supported paired-end naming:
  *_R1.fastq.gz     ↔ *_R2.fastq.gz
  *_R1.fastq        ↔ *_R2.fastq
  *_R1_001.fastq.gz ↔ *_R2_001.fastq.gz
  *_R1_001.fastq    ↔ *_R2_001.fastq
  *_1.fastq.gz      ↔ *_2.fastq.gz
  *_1.fastq         ↔ *_2.fastq

Notes:
  - Sample prefix is the part before the first underscore in the R1 filename.
  - Compressed (.gz) and uncompressed (.fastq) are both supported.
HLP
}

while getopts "i:o:h" opt; do
  case ${opt} in
    i) INPUT_DIR="${OPTARG%/}" ;;
    o) OUTPUT_DIR="${OPTARG%/}" ;;
    h) show_help; exit 0 ;;
    *) show_help; exit 1 ;;
  esac
done

if [[ -z "${INPUT_DIR}" || -z "${OUTPUT_DIR}" ]]; then
  echo "Error: -i and -o are required."
  show_help
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

# Helper: compute R2 path and sample name from an R1 path
get_pair_and_names() {
  local r1="$1"
  local base ext name r2
  base="$(basename "$r1")"

  # Determine extension (.fastq or .fastq.gz)
  if [[ "$base" == *.fastq.gz ]]; then
    ext=".fastq.gz"
  elif [[ "$base" == *.fastq ]]; then
    ext=".fastq"
  else
    echo "skip" ""; return 0
  fi

  if [[ "$base" == *_R1_001"$ext" ]]; then
    name="${base%_R1_001$ext}"
    r2="${r1/_R1_001$ext/_R2_001$ext}"
  elif [[ "$base" == *_R1"$ext" ]]; then
    name="${base%_R1$ext}"
    r2="${r1/_R1$ext/_R2$ext}"
  elif [[ "$base" == *_1"$ext" ]]; then
    name="${base%_1$ext}"
    r2="${r1/_1$ext/_2$ext}"
  else
    echo "skip" ""; return 0
  fi

  # Prefix = characters before the first underscore
  local prefix="${name%%_*}"
  echo "$r2" "$prefix"
}

# Find all supported R1 files (covers gz + uncompressed)
while IFS= read -r -d '' R1; do
  # Compute R2 + output prefix
  read -r R2 PREFIX < <(get_pair_and_names "$R1")
  [[ "$R2" == "skip" ]] && continue

  if [[ ! -f "$R2" ]]; then
    echo "⚠️  Skipping $(basename "$R1"): matching R2 not found."
    continue
  fi

  echo "Running: ska fastq \"$R1\" \"$R2\" -o \"${OUTPUT_DIR}/${PREFIX}\""
  ska fastq "$R1" "$R2" -o "${OUTPUT_DIR}/${PREFIX}"

done < <(find "$INPUT_DIR" -type f \( \
           -name "*_R1.fastq.gz"   -o -name "*_R1.fastq"      -o \
           -name "*_R1_001.fastq.gz" -o -name "*_R1_001.fastq" -o \
           -name "*_1.fastq.gz"    -o -name "*_1.fastq" \
         \) -print0 | sort -z)

