#!/usr/bin/env python

# Get number of reads and bases in R1 and R2 files and totals for a single sample

import argparse
from Bio import SeqIO
import gzip
import os
import re
from typing import Tuple, Iterable

def parse_args():
    p = argparse.ArgumentParser(
        description="Compute read counts, base counts, and coverage for one sample."
    )
    p.add_argument(
        "-r", "--reads_files", nargs="+", required=True,
        help="One or two FASTQ/FASTQ.GZ files for the sample (e.g., R1 and R2)."
    )
    p.add_argument(
        "-g", "--genome_size", required=True, type=int,
        help="Genome size (bp), e.g., 3000000"
    )
    return p.parse_args()

def number_of_bases(path: str) -> Tuple[int, int]:
    """
    Return (num_bases, num_reads) in a FASTQ(.gz).
    """
    opener = gzip.open if path.endswith(".gz") else open
    mode = "rt"
    num_bases = 0
    num_reads = 0
    with opener(path, mode) as handle:
        for rec in SeqIO.parse(handle, "fastq"):
            num_bases += len(rec)
            num_reads += 1
    return num_bases, num_reads

# (Kept only as a reference — not used. If you ever re-enable, note the raw string.)
# count_base_output_re = re.compile(r'Num reads:(\d+)\tNum Bases: (\d+)\n')

def main():
    args = parse_args()

    reads: Iterable[str] = sorted(args.reads_files)
    if len(reads) > 2:
        raise SystemExit("Provide at most TWO read files (-r R1 R2).")
    # Allow single-end (1 file) or paired-end (2 files)

    # Sample name: characters before first underscore in the FIRST read file
    first = os.path.basename(reads[0])
    sample = first.split("_", 1)[0]

    info = [sample]
    total_bases = 0
    total_reads = 0

    # For consistency, report in the order of sorted filenames (R1 then R2 usually)
    per_file = []
    for path in reads:
        bases, reads_count = number_of_bases(path)
        per_file.append((reads_count, bases))
        total_bases += bases
        total_reads += reads_count

    # Emit per-file (reads, bases)
    for reads_count, bases in per_file:
        info += [reads_count, bases]

    cov = total_bases / float(args.genome_size)
    info += [total_reads, total_bases, round(cov, 2)]

    # TSV to stdout
    print("\t".join(str(x) for x in info))

if __name__ == "__main__":
    main()

