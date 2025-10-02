Useful Scripts for Bioinformatic Analyses

# spades.sh 
Script is comptabile with SPAdes genome assembler v3.15.5. Usage is sh spades.sh /path/to/paired/reads
If reads do not end in R1_001 or R2_001, update script accordingly. Assemblies will be put in a folder named "contigs". Assembly IDs are labeled based on read file names.

# rename_contigs.sh 
For all .fasta files in a folder, will prefix lines that start with ">" (aka contigs) with respective assembly ID. Usage is sh rename_contigs.sh /path/to/fastas

# prokka.sh
Will run on all .fasta or .fna in assemblies folder, will create a new folder "prokka" which has output and locus-tag prefixed by assembly ID. Usage sh prokka.sh -i Specify the input directory containing .fasta or .fna files -o Specify the output directory for prokka results. (default: ./prokka)

# filter_contigs_length.sh
Removes length of all contigs based on length threshold. Must have bbmap installed via conda to run the script. To change the threshold, update line 13 accordingly. Usage is sh filter_contigs_length.sh /path/to/fastas 
If genomes are in .fna, update the script accordingly

# amrfinder.sh
Runs amrfinder on all assemblies in a folder. Can handle both .fna and .fasta files. Usage sh amrfinder.sh -i /path/to/input_directory -o combined_output.tsv -O SpeciesDatabase. Please see the available chromosomal databases https://github.com/ncbi/amr/wiki/Running-AMRFinderPlus#--organism-option
# combined_contigs.sh
Combined all contigs in a assembly file, specifically a .fna, into 1 contig. If your assemblies end in .fasta or another extention please edit the script accordingly. 

# run_tracs.sh 
Runs tracs align on reads in input folder. Reads must end in .fastq.gz. The script prefixes the outputs based on the string of characters before "_", so for example DVT1234_S12_fastq.gz, the prefix would be DVT1234. The usage is bash run_tracs.sh -i path/to/reads -o /path/to/output --db path/to/database/

# bakta.sh
Runs bakta on fasta or fna files in input folder. The script prefixes output files and locus-tags with input filenames. The usage is bakta.sh -i /path/to/input_dir -o /path/to/output_dir -d /path/to/db

# quast.sh
Runs QUAST on all assembly files in a folder. Creates individual output folders named based on input assembly name. Summarizes QC results across all input files into an excel sheet. Usage is: sh quast.sh -i /path/to/assemblies -o quast_results -f quast_summary.xlsx

# read_depth_Multiple.py
Calculates read coverage based on paired-end reads and genome size. Searches quast_summary.xlsx file for genome size and matches the sample ID with the paired end read name. Therefore, quast.sh must be run before using read_depth_Multiple.py. The tool will calculate coverage for each input sample and combine the results into summary excel sheet. Usage is: python read_depth_Multiple.py -r /path/to/reads -q /path/to/quast_summary.xlsx -o read_coverage.xlsx

# kraken.sh
Runs kraken2 on all paired end reads in input folder. Creates summary file of the top three species hits for each sample. Creates kraken output and report text files for each input sample prefixed by input read name. Change line 52 to database path on your system. Usage is: kraken2.sh -i path/to/reads -o kraken_results -f kraken2_summary.xlsx

# subsample.sh 
Runs the reformat.sh tool from package bbtools to subsample paired end reads based on target read value. To change the sample read target value, edit line 100. The script will make new read files with "SUB" added to the read filename. Usage is: sh susample.sh /path/to/input/reads -o output/reads/folder

# ska_fastq.sh 
Runs split kmer analysis on paired end reads in a folder and will produce a split kmer file for each paired read. Usage is: sh ska_fastq.sh -i /path/to/reads -o ska_fastq 

# find_clusters_SKA.py
The find_cluster_SKA.py work specifically to find clusters based on SKA distance output. It produces a matrix of pairwise distances for each sample (matrix.csv) and the list of all samples belonging to a cluster. Clusters are named by letter. If samples have the same letter they are in the same cluster. If samples are not in this list it means they are not in a cluster. Usage is: python find_clusters_SKA.py -i /path/to/SKA.distance.tsv -o clusters.tsv -m average -t 10 --from_ska where -m is the method for average linkage and -t is the imposed threshold of 10 



