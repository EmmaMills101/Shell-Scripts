#!/bin/bash

# Subsample paired-end reads to 3,000,000 read pairs using BBTools reformat.sh
# Supports:
#   *_R1.fastq.gz     ↔ *_R2.fastq.gz
#   *_R1_001.fastq.gz ↔ *_R2_001.fastq.gz
#   *_R1.fastq        ↔ *_R2.fastq
#   *_R1_001.fastq    ↔ *_R2_001.fastq
#   *_1.fastq.gz      ↔ *_2.fastq.gz
#   *_1.fastq         ↔ *_2.fastq

usage() {
  echo ""
  echo "Usage: $0 -i <input_directory> [-o <output_directory>]"
  echo ""
  echo "Options:"
  echo "  -i    Path to input directory containing paired-end FASTQ files"
  echo "  -o    Path to output directory (default: <input_directory>/subsampled)"
  echo "  -h    Show this help message"
  echo ""
  echo "Output files are written as <prefix>_SUB_R1_001.fastq[.gz] and <prefix>_SUB_R2_001.fastq[.gz]"
}

# ---- Parse arguments ----
while getopts "i:o:h" opt; do
  case $opt in
    i) INPUT_DIR="$OPTARG" ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

# ---- Validate ----
if [[ -z "${INPUT_DIR:-}" ]]; then
  echo "❌ Error: Input directory (-i) is required."
  usage
  exit 1
fi
if [[ ! -d "$INPUT_DIR" ]]; then
  echo "❌ Error: Directory not found: $INPUT_DIR"
  exit 1
fi
OUTPUT_DIR="${OUTPUT_DIR:-${INPUT_DIR%/}/subsampled}"
mkdir -p "$OUTPUT_DIR"

# ---- Helper: given an R1 path, return 'R2|prefix|ext' or 'SKIP||' ----
pair_info() {
  local r1="$1"
  local base ext prefix r2

  if [[ "$r1" == *.fastq.gz ]]; then
    ext=".fastq.gz"
  else
    ext=".fastq"
  fi

  base="$(basename "$r1")"

  if   [[ "$base" == *_R1_001$ext ]]; then
    prefix="${base%_R1_001$ext}"
    r2="${r1/_R1_001$ext/_R2_001$ext}"
  elif [[ "$base" == *_R1$ext ]]; then
    prefix="${base%_R1$ext}"
    r2="${r1/_R1$ext/_R2$ext}"
  elif [[ "$base" == *_1$ext ]]; then
    prefix="${base%_1$ext}"
    r2="${r1/_1$ext/_2$ext}"
  else
    echo "SKIP||"
    return
  fi

  echo "${r2}|${prefix}|${ext}"
}

# ---- Walk inputs and subsample ----
find "$INPUT_DIR" -type f \( \
  -name "*_R1_001.fastq.gz" -o -name "*_R1.fastq.gz"   -o \
  -name "*_R1_001.fastq"    -o -name "*_R1.fastq"      -o \
  -name "*_1.fastq.gz"      -o -name "*_1.fastq" \
\) -print0 | while IFS= read -r -d '' R1_FILE; do

  info="$(pair_info "$R1_FILE")"
  IFS='|' read -r R2_FILE PREFIX EXT <<< "$info"

  if [[ "$R2_FILE" == "SKIP" ]]; then
    echo "Skipping $(basename "$R1_FILE"): unsupported R1 pattern."
    continue
  fi
  if [[ ! -f "$R2_FILE" ]]; then
    echo "⚠️  Matching R2 not found for: $R1_FILE — skipping."
    continue
  fi

  OUT1="$OUTPUT_DIR/${PREFIX}_SUB_R1_001$EXT"
  OUT2="$OUTPUT_DIR/${PREFIX}_SUB_R2_001$EXT"

  echo "🔄 Subsampling ${PREFIX} → $(basename "$OUT1"), $(basename "$OUT2")"
  reformat.sh in1="$R1_FILE" in2="$R2_FILE" out1="$OUT1" out2="$OUT2" samplereadstarget=3000000

done

echo ""
echo "✅ Subsampling complete."
echo "📁 Output: $OUTPUT_DIR"

