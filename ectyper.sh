#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'EOF'
Usage:
  ectyper_batch.sh -i INPUT_DIR -o OUTPUT_DIR [-t CORES] [-r REF_MASH]

Run ECTyper on all assemblies in INPUT_DIR ending with .fasta, .fna, or .fa.
Creates OUTPUT_DIR/<stem>/ per sample (stem = filename without extension)
and a 2-column summary:
  OUTPUT_DIR/ectyper_summary.tsv  (sample<TAB>serotype)

Options:
  -i   Input directory with .fasta/.fna/.fa assemblies (non-recursive)
  -o   Parent output directory to hold per-sample subfolders
  -t   CPU cores for ECTyper (default: 4)
  -r   Optional explicit path to EnteroRef *.msh (overrides auto-detect)
  -h   Help
EOF
}

THREADS=4
INPUT_DIR=""
OUTPUT_DIR=""
REF_MASH=""

while getopts ":i:o:t:r:h" opt; do
  case "$opt" in
    i) INPUT_DIR="$OPTARG" ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    t) THREADS="$OPTARG" ;;
    r) REF_MASH="$OPTARG" ;;
    h) show_help; exit 0 ;;
    \?) echo "Error: Invalid option -$OPTARG" >&2; show_help; exit 1 ;;
    :)  echo "Error: Option -$OPTARG requires an argument." >&2; show_help; exit 1 ;;
  esac
done

[[ -z "$INPUT_DIR" || -z "$OUTPUT_DIR" ]] && { echo "Error: -i and -o are required." >&2; show_help; exit 1; }
[[ -d "$INPUT_DIR" ]] || { echo "Error: INPUT_DIR not found: $INPUT_DIR" >&2; exit 1; }

# ---- Locate ECTyper's Data dir & default sketch path ----
ECTYPER_DATA_DIR=$(python3 - <<'PY'
import inspect, os, sys
try:
    import ectyper
    print(os.path.join(os.path.dirname(inspect.getfile(ectyper)), "Data"))
except Exception:
    sys.exit(1)
PY
) || { echo "Error: Could not import ectyper. Activate the ectyper env first."; exit 1; }

DEFAULT_SKETCH="${ECTYPER_DATA_DIR}/EnteroRef_GTDBSketch_20231003_V2.msh"
REF_TO_USE="${REF_MASH:-$DEFAULT_SKETCH}"

# ---- Preflight sketch ----
LOCK_FILE="${ECTYPER_DATA_DIR}/.lock"
[[ -f "$LOCK_FILE" ]] && rm -f "$LOCK_FILE" || true
if [[ ! -s "$REF_TO_USE" ]]; then
  echo "Error: ECTyper species-ID sketch not found at: $REF_TO_USE"
  echo "Install it into: $DEFAULT_SKETCH   (or pass -r /path/to/*.msh)"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
SUMMARY="$OUTPUT_DIR/ectyper_summary.tsv"
: > "$SUMMARY"
echo -e "sample\tserotype" >> "$SUMMARY"

# ---- Gather inputs (.fasta, .fna, .fa) ----
shopt -s nullglob
mapfile -t files < <(printf "%s\n" "$INPUT_DIR"/*.fasta "$INPUT_DIR"/*.fna "$INPUT_DIR"/*.fa 2>/dev/null | grep -E '\.(fasta|fna|fa)$' | sort)
if (( ${#files[@]} == 0 )); then
  echo "No .fasta, .fna, or .fa files found in $INPUT_DIR"
  exit 0
fi

echo "ECTyper Data dir: $ECTYPER_DATA_DIR"
echo "Using sketch:     $REF_TO_USE"
echo "Found ${#files[@]} assemblies. Starting…"
echo

# Detect duplicate stems to avoid clobbering
declare -A seen=()
for asm in "${files[@]}"; do
  fname="$(basename "$asm")"
  stem="${fname%.*}"     # remove only the last extension
  if [[ -n "${seen[$stem]:-}" ]]; then
    echo "[WARN] Multiple inputs map to the same sample stem '$stem' (e.g., $fname and ${seen[$stem]}). Skipping $fname."
  else
    seen[$stem]="$fname"
  fi
done

for asm in "${files[@]}"; do
  fname="$(basename "$asm")"
  stem="${fname%.*}"
  # Skip duplicates by stem
  [[ "${seen[$stem]}" != "$fname" ]] && continue

  sample_out="$OUTPUT_DIR/$stem"
  mkdir -p "$sample_out"

  # Skip if prior results present
  if compgen -G "$sample_out/"'*.tsv' > /dev/null || compgen -G "$sample_out/"'*.json' > /dev/null; then
    echo "[SKIP] $fname -> existing results in $sample_out"
  else
    echo "[RUN ] $fname  -> $stem/"
    ectyper \
      --input "$asm" \
      --output "$sample_out" \
      -c "$THREADS" \
      --reference "$REF_TO_USE"
    echo "[DONE] $fname"
  fi

  # -------- Extract serotype into the summary (TSV preferred) --------
  serotype=""
  tsv_file=""
  for f in "$sample_out"/*.tsv; do [[ -e "$f" ]] && { tsv_file="$f"; break; }; done

  if [[ -n "$tsv_file" ]]; then
    sero_col="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++){l=tolower($i); if(l ~ /serotype/) {print i; exit}}}' "$tsv_file")"
    if [[ -n "${sero_col:-}" ]]; then
      serotype="$(awk -F'\t' -v c="$sero_col" 'NR>1{print $c; exit}' "$tsv_file")"
    fi
    if [[ -z "$serotype" ]]; then
      Ocol="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++){l=tolower($i); if(l=="o"||l=="otype"||l=="o_type"||l=="o-type"||l=="o_antigen"||l=="otype_call"||l=="o_type_call") {print i; exit}}}' "$tsv_file")"
      Hcol="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++){l=tolower($i); if(l=="h"||l=="htype"||l=="h_type"||l=="h-type"||l=="h_antigen"||l=="htype_call"||l=="h_type_call") {print i; exit}}}' "$tsv_file")"
      if [[ -n "${Ocol:-}" && -n "${Hcol:-}" ]]; then
        O="$(awk -F'\t' -v c="$Ocol" 'NR>1{print $c; exit}' "$tsv_file")"
        H="$(awk -F'\t' -v c="$Hcol" 'NR>1{print $c; exit}' "$tsv_file")"
        [[ -n "${O}${H}" ]] && serotype="O${O}:H${H}"
      fi
    fi
  fi

  # JSON fallback (best-effort)
  if [[ -z "$serotype" && -z "${tsv_file:-}" ]]; then
    json_file=""
    for f in "$sample_out"/*.json; do [[ -e "$f" ]] && { json_file="$f"; break; }; done
    if [[ -n "$json_file" ]]; then
      set +e
      serotype="$(python3 - "$json_file" <<'PY' 2>/dev/null
import json, sys
p = sys.argv[1]
with open(p) as fh:
    obj = json.load(fh)

def get_ci(d, k):
    for kk, vv in d.items():
        if kk.lower()==k: return vv
    return None

s = None
if isinstance(obj, dict):
    s = get_ci(obj, "serotype")
if isinstance(s, str) and s.strip():
    print(s.strip()); raise SystemExit

def walk(x):
    if isinstance(x, dict):
        s = get_ci(x, "serotype")
        if isinstance(s, str) and s.strip():
            print(s.strip()); raise SystemExit
        for v in x.values(): walk(v)
    elif isinstance(x, list):
        for v in x: walk(v)
walk(obj)

O = None; H = None
def find_types(x):
    global O,H
    if isinstance(x, dict):
        for k,v in x.items():
            lk = k.lower()
            if lk in ("o","otype","o_type","o-type","o_antigen","otype_call","o_type_call"):
                if isinstance(v,str) and v.strip(): O = O or v.strip()
            if lk in ("h","htype","h_type","h-type","h_antigen","htype_call","h_type_call"):
                if isinstance(v,str) and v.strip(): H = H or v.strip()
        for v in x.values(): find_types(v)
    elif isinstance(x, list):
        for v in x: find_types(v)
find_types(obj)
if O or H:
    print(f"O{O}:H{H}".replace("None","?"))
PY
)"
      set -e
    fi
  fi

  [[ -z "$serotype" ]] && serotype="NA"
  printf "%s\t%s\n" "$stem" "$serotype" >> "$SUMMARY"
done

echo "Summary written to: $SUMMARY"
echo "All done. Outputs are in: $OUTPUT_DIR"

