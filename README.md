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




