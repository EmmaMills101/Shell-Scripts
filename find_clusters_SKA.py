#!/usr/bin/env python

import matplotlib
matplotlib.use('Agg')

import argparse
import pandas as pd
import numpy as np
from scipy.cluster.hierarchy import linkage, fcluster
from scipy.spatial.distance import squareform

def number_to_letters(n):
    """Convert number to Excel-style letters: 0 -> A, 25 -> Z, 26 -> AA, etc."""
    result = ''
    while n >= 0:
        result = chr(n % 26 + ord('A')) + result
        n = n // 26 - 1
    return result

def convert_ska_to_matrix(input_file, output_file="matrix.csv"):
    try:
        df = pd.read_csv(input_file, sep="\t")
    except Exception as e:
        raise ValueError(f"Error reading input file: {e}")

    expected_columns = {"Sample 1", "Sample 2", "SNPs"}
    if not expected_columns.issubset(df.columns):
        raise ValueError(f"Input file must contain columns: {expected_columns}")

    df = df[["Sample 1", "Sample 2", "SNPs"]].dropna()
    try:
        df["SNPs"] = df["SNPs"].astype(float)
    except ValueError:
        raise ValueError("Could not convert 'SNPs' column to float.")

    samples = sorted(set(df["Sample 1"]).union(df["Sample 2"]))
    matrix = pd.DataFrame(np.nan, index=samples, columns=samples)

    for _, row in df.iterrows():
        s1, s2, dist = row["Sample 1"], row["Sample 2"], row["SNPs"]
        matrix.at[s1, s2] = dist
        matrix.at[s2, s1] = dist

    for s in samples:
        matrix.at[s, s] = 0.0

    matrix.to_csv(output_file)
    return output_file

def cluster_matrix(matrix_file, method="average", threshold=20, output_file="clusters.csv"):
    df = pd.read_csv(matrix_file, index_col=0)
    df.fillna(0, inplace=True)
    np.fill_diagonal(df.values, 0)

    condensed = squareform(df.values)
    Z = linkage(condensed, method=method)
    numeric_clusters = fcluster(Z, t=threshold, criterion='distance')

    cluster_df = pd.DataFrame({"Sample": df.index, "ClusterNum": numeric_clusters})
    cluster_sizes = cluster_df["ClusterNum"].value_counts()
    valid_clusters = cluster_sizes[cluster_sizes > 1].index
    filtered_df = cluster_df[cluster_df["ClusterNum"].isin(valid_clusters)].copy()

    # Assign letter labels even if there are more than 26 clusters
    cluster_map = {num: number_to_letters(i) for i, num in enumerate(sorted(valid_clusters))}
    filtered_df["Cluster"] = filtered_df["ClusterNum"].map(cluster_map)

    # Return only relevant columns and sort by cluster label then sample
    filtered_df = filtered_df[["Sample", "Cluster"]]
    filtered_df = filtered_df.sort_values(by=["Cluster", "Sample"])

    filtered_df.to_csv(output_file, index=False)
    print(f"Clustering is complete! Results saved to {output_file}")

def main():
    parser = argparse.ArgumentParser(description="Cluster samples from SNP distances")
    parser.add_argument("-i", "--input", required=True, help="Input distance file (SKA format or matrix)")
    parser.add_argument("-m", "--method", choices=["average", "single", "complete"], default="average", help="Clustering linkage method")
    parser.add_argument("--from_ska", action="store_true", help="Indicates the input is a SKA .distances.tsv file with a SNPs column")
    parser.add_argument("-t", "--threshold", type=float, default=20, help="Clustering threshold")
    parser.add_argument("-o", "--output", required=True, help="Exact name of output CSV file (e.g., clusters.csv)")
    args = parser.parse_args()
    if args.from_ska:
        matrix_file = convert_ska_to_matrix(args.input)
    else:
        matrix_file = args.input
    cluster_matrix(matrix_file, method=args.method, threshold=args.threshold, output_file=args.output)

if __name__ == "__main__":
    main()

