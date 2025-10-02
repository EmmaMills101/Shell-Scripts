#!/usr/bin/env python

import argparse
from Bio import SeqIO
import gzip
import os
import re
import pandas as pd
import glob
from typing import Optional, Tuple, Dict, Any, List

def parse_args():
    parser = argparse.ArgumentParser(
        description="Calculate read depth using paired-end reads and QUAST genome sizes."
    )
    parser.add_argument('-r', '--reads', required=True, help="Folder containing reads")
    parser.add_argument('-q', '--quast', required=True, help="Path to QUAST .xlsx file")
    parser.add_argument('-o', '--output', required=True, help="Path to output Excel file")
    return parser.parse_args()

def number_of_bases(filepath: str) -> Tuple[int, int]:
    num_reads, num_bases = 0, 0
    opener = gzip.open if filepath.endswith('.gz') else open
    mode = 'rt' if filepath.endswith('.gz') else 'r'
    with opener(filepath, mode) as handle:
        for record in SeqIO.parse(handle, 'fastq'):
            num_reads += 1
            num_bases += len(record)
    return num_reads, num_bases

# R1 suffix remover: supports _R1.fastq[.gz], _R1_001.fastq[.gz], _1.fastq[.gz]
R1_SUFFIX_RE = re.compile(r'_(?:R1(?:_001)?|1)\.fastq(?:\.gz)?$')

def get_sample_id_from_r1(filepath: str) -> str:
    base = os.path.basename(filepath)
    return R1_SUFFIX_RE.sub('', base)

def mate_for_r1(r1_path: str) -> Optional[str]:
    """
    Given an R1 filepath, return the expected R2 filepath using the same scheme and extension.
    """
    base = os.path.basename(r1_path)
    dirn = os.path.dirname(r1_path)
    gz = base.endswith('.gz')
    ext = '.fastq.gz' if gz else '.fastq'

    if re.search(r'_R1_001\.fastq(?:\.gz)?$', base):
        r2_base = re.sub(r'_R1_001\.fastq(?:\.gz)?$', '_R2_001' + ext, base)
    elif re.search(r'_R1\.fastq(?:\.gz)?$', base):
        r2_base = re.sub(r'_R1\.fastq(?:\.gz)?$', '_R2' + ext, base)
    elif re.search(r'_1\.fastq(?:\.gz)?$', base):
        r2_base = re.sub(r'_1\.fastq(?:\.gz)?$', '_2' + ext, base)
    else:
        return None

    candidate = os.path.join(dirn, r2_base)
    return candidate if os.path.exists(candidate) else None

def build_genome_size_map(quast_xlsx_path: str) -> Dict[str, Any]:
    """
    Build a lookup that can resolve either the full name or the name before the first underscore.
    Prefers full-name keys; also stores trimmed-first-underscore keys.
    """
    df = pd.read_excel(quast_xlsx_path)

    # Try to find a reasonable sample column
    if 'Sample' not in df.columns:
        # Fall back to first column if 'Sample' missing
        df['Sample'] = df.iloc[:, 0]

    if 'Total length' not in df.columns:
        raise ValueError("QUAST file is missing a 'Total length' column.")

    df['Sample'] = df['Sample'].astype(str)
    df['Total length'] = pd.to_numeric(df['Total length'], errors='coerce')

    # Build map: exact and trimmed (before first underscore)
    genome_size_map: Dict[str, Any] = {}
    for _, row in df.iterrows():
        sample = str(row['Sample'])
        total_len = row['Total length']
        if pd.isna(total_len):
            continue
        genome_size_map[sample] = total_len
        trimmed = sample.split('_', 1)[0]
        # Only set trimmed if not already set to avoid overriding exact duplicates
        genome_size_map.setdefault(trimmed, total_len)

    return genome_size_map

def resolve_genome_size(sample_id: str, gmap: Dict[str, Any]) -> Tuple[Optional[float], str]:
    """
    Try exact sample_id, then the part before first underscore.
    Returns (genome_size, matched_key).
    """
    if sample_id in gmap:
        return float(gmap[sample_id]), sample_id
    trimmed = sample_id.split('_', 1)[0]
    if trimmed in gmap:
        return float(gmap[trimmed]), trimmed
    return None, ""

def main():
    args = parse_args()

    # Build genome-size lookup (supports exact and before-underscore keys)
    genome_size_map = build_genome_size_map(args.quast)

    # Gather R1 files
    r1_patterns = [
        '*_R1.fastq', '*_R1.fastq.gz',
        '*_R1_001.fastq', '*_R1_001.fastq.gz',
        '*_1.fastq', '*_1.fastq.gz'
    ]
    r1_files: List[str] = []
    for pattern in r1_patterns:
        r1_files.extend(glob.glob(os.path.join(args.reads, pattern)))
    r1_files = sorted(set(r1_files))

    if not r1_files:
        print("No R1 files found with supported patterns in:", args.reads)

    results = []

    for r1 in r1_files:
        sample_id = get_sample_id_from_r1(r1)
        r2 = mate_for_r1(r1)

        if not r2:
            print(f"⚠️  Skipping {sample_id}: No matching R2 found for {os.path.basename(r1)}.")
            continue

        genome_size, matched_key = resolve_genome_size(sample_id, genome_size_map)
        if genome_size is None:
            print(f"⚠️  Skipping {sample_id}: Genome size not found in QUAST (checked '{sample_id}' and '{sample_id.split('_',1)[0]}').")
            continue

        # Count reads/bases
        r1_reads, r1_bases = number_of_bases(r1)
        r2_reads, r2_bases = number_of_bases(r2)
        total_reads = r1_reads + r2_reads
        total_bases = r1_bases + r2_bases
        coverage = total_bases / float(genome_size) if genome_size else 0.0

        # Optional: print which key matched for transparency
        if matched_key != sample_id:
            print(f"ℹ️  {sample_id}: matched QUAST sample '{matched_key}'")

        results.append([
            sample_id, matched_key, genome_size,
            r1_reads, r1_bases, r2_reads, r2_bases,
            total_reads, total_bases, round(coverage, 2)
        ])

    # Save results
    cols = [
        'Sample', 'QUAST_Key_Used', 'Genome_Size',
        'R1_Reads', 'R1_Bases', 'R2_Reads', 'R2_Bases',
        'Total_Reads', 'Total_Bases', 'Coverage'
    ]
    out_df = pd.DataFrame(results, columns=cols)
    out_df.to_excel(args.output, index=False)

    print(f"\n✅ Coverage report complete! Output saved to: {args.output}")

if __name__ == '__main__':
    main()

