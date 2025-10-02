#!/bin/bash
set -euo pipefail

show_help() {
    cat <<'HLP'
Usage:
  bash kraken2.sh -i INPUT_DIR -o OUTPUT_DIR -f SUMMARY_FILE.xlsx

Required:
  -i   Input directory containing paired-end FASTQ/FASTQ.GZ files
  -o   Output directory; "classifications/" and "reports/" will be created
  -f   Summary Excel filename (e.g., kraken_summary.xlsx)

Supported paired-end naming:
  *_R1.fastq.gz    / *_R2.fastq.gz
  *_R1.fastq       / *_R2.fastq
  *_R1_001.fastq.gz/ *_R2_001.fastq.gz
  *_R1_001.fastq   / *_R2_001.fastq
  *_1.fastq.gz     / *_2.fastq.gz
  *_1.fastq        / *_2.fastq

Notes:
  - Gzip is auto-detected; --gzip-compressed is added only for .gz inputs.
  - Outputs use the sample name BEFORE the first underscore in R1
    (e.g., ACIN00200_S84_R1.fastq.gz -> ACIN00200_report.txt / ACIN00200_output.txt).
HLP
}

# ---- Parse args ----
INPUT_DIR=""
OUTPUT_DIR=""
SUMMARY_FILE=""

while getopts "i:o:f:h" opt; do
    case $opt in
        i) INPUT_DIR="${OPTARG%/}" ;;
        o) OUTPUT_DIR="${OPTARG%/}" ;;
        f) SUMMARY_FILE="$OPTARG" ;;
        h) show_help; exit 0 ;;
        *) show_help; exit 1 ;;
    esac
done

if [[ -z "${INPUT_DIR}" || -z "${OUTPUT_DIR}" || -z "${SUMMARY_FILE}" ]]; then
    echo "❌ Error: -i, -o and -f are required."
    show_help
    exit 1
fi

# ---- Config (edit DB_PATH to your local Kraken2 DB) ----
DB_PATH="/home/cdc/Desktop/k2_standard_16gb"

# ---- Create output dirs ----
REPORT_DIR="${OUTPUT_DIR}/reports"
CLASSIFICATION_DIR="${OUTPUT_DIR}/classifications"
mkdir -p "${REPORT_DIR}" "${CLASSIFICATION_DIR}"

# ---- Helpers ----

# Given an R1 filename, return the mate R2 using the same scheme & compression
get_r2_path() {
    local r1="$1"
    local base dir ext
    base="$(basename "$r1")"
    dir="$(dirname "$r1")"

    if [[ "$base" =~ \.fastq\.gz$ ]]; then
        ext=".fastq.gz"
    else
        ext=".fastq"
    fi

    local r2base=""
    if   [[ "$base" =~ _R1_001\.fastq(\.gz)?$ ]]; then
        r2base="${base/_R1_001$ext/_R2_001$ext}"
    elif [[ "$base" =~ _R1\.fastq(\.gz)?$ ]]; then
        r2base="${base/_R1$ext/_R2$ext}"
    elif [[ "$base" =~ _1\.fastq(\.gz)?$ ]]; then
        r2base="${base/_1$ext/_2$ext}"
    else
        echo ""; return
    fi

    local candidate="${dir}/${r2base}"
    [[ -f "$candidate" ]] && echo "$candidate" || echo ""
}

# Sample stem from R1 (strip only the R1/1 suffix)
sample_from_r1_stem() {
    local base="$1"
    base="${base%_R1.fastq}"
    base="${base%_R1.fastq.gz}"
    base="${base%_R1_001.fastq}"
    base="${base%_R1_001.fastq.gz}"
    base="${base%_1.fastq}"
    base="${base%_1.fastq.gz}"
    echo "$base"
}

# Short sample = characters BEFORE the first underscore of the stem
short_sample() {
    local stem="$1"
    echo "${stem%%_*}"
}

# ---- Find R1 files (all supported patterns) ----
mapfile -t R1_FILES < <(find "$INPUT_DIR" -type f \( \
    -name "*_R1.fastq.gz" -o -name "*_R1.fastq" -o \
    -name "*_R1_001.fastq.gz" -o -name "*_R1_001.fastq" -o \
    -name "*_1.fastq.gz" -o -name "*_1.fastq" \
\) | sort)

if [[ ${#R1_FILES[@]} -eq 0 ]]; then
    echo "⚠️  No R1 files found under: $INPUT_DIR"
fi

# ---- Run Kraken2 for each pair ----
for r1 in "${R1_FILES[@]}"; do
    [[ -f "$r1" ]] || continue

    base="$(basename "$r1")"
    stem="$(sample_from_r1_stem "$base")"
    sample_short="$(short_sample "$stem")"

    r2="$(get_r2_path "$r1")"
    if [[ -z "$r2" ]]; then
        echo "⚠️  Skipping ${sample_short}: could not find matching R2 for $(basename "$r1")"
        continue
    fi

    out_txt="${CLASSIFICATION_DIR}/${sample_short}_output.txt"
    rep_txt="${REPORT_DIR}/${sample_short}_report.txt"

    if [[ -f "$out_txt" && -f "$rep_txt" ]]; then
        echo "⏭️  Skipping ${sample_short} — output already exists."
        continue
    fi

    echo "🧬 Running Kraken2 for ${sample_short}"

    extra=()
    if [[ "$r1" == *.gz || "$r2" == *.gz ]]; then
        extra+=(--gzip-compressed)
    fi

    kraken2 \
        --db "$DB_PATH" \
        --paired \
        --use-names \
        --output "$out_txt" \
        --report "$rep_txt" \
        "${extra[@]:-}" \
        "$r1" "$r2"
done

# ---- Summarize reports into Excel (requires openpyxl) ----
echo "📊 Summarizing Kraken2 reports..."

python3 <<EOF
import os, glob
import pandas as pd

report_dir = "${REPORT_DIR}"
out_excel = os.path.join("${OUTPUT_DIR}", "${SUMMARY_FILE}")

paths = sorted(glob.glob(os.path.join(report_dir, "*_report.txt")))
rows = []

def parse_pct(line: str) -> float:
    try:
        return float(line.split("\\t", 1)[0])
    except Exception:
        return 0.0

for path in paths:
    # sample names in reports are already the short form (before first underscore)
    sample = os.path.basename(path).rsplit("_report.txt", 1)[0]
    with open(path, "r", encoding="utf-8", errors="ignore") as fh:
        lines = fh.readlines()

    unclassified_line = next((l for l in lines if l.strip().endswith("unclassified")), None)
    pct_unclassified = parse_pct(unclassified_line) if unclassified_line else 0.0
    pct_classified = max(0.0, 100.0 - pct_unclassified)

    species_lines = [l for l in lines if "\\tS\\t" in l]
    species_lines.sort(key=parse_pct, reverse=True)

    top = []
    for l in species_lines[:3]:
        pct = parse_pct(l)
        name = l.strip().split("\\t")[-1].strip()
        top.extend([name, pct])
    while len(top) < 6:
        top.extend(["", ""])

    rows.append([sample, pct_classified, pct_unclassified] + top)

columns = [
    "Sample", "% Classified", "% Unclassified",
    "Top1_Species", "Top1_%", "Top2_Species", "Top2_%", "Top3_Species", "Top3_%"
]
df = pd.DataFrame(rows, columns=columns)

with pd.ExcelWriter(out_excel, engine="openpyxl") as xw:
    df.to_excel(xw, index=False)

print(f"✅ Excel summary written to {out_excel}")
EOF

echo "✅ Kraken2 processing complete!"
echo "🗂 Reports:          ${REPORT_DIR}"
echo "📄 Classifications:  ${CLASSIFICATION_DIR}"
echo "📊 Summary Excel:    ${OUTPUT_DIR}/${SUMMARY_FILE}"

