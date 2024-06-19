Useful Scripts for Bioinformatic Analyses

# spades.sh 
Script is comptabile with SPAdes genome assembler v3.15.5. Usage is sh spades.sh /path/to/paired/reads
If reads do not end in R1_001 or R2_001, update script based accordingly. Assemblies will be put in a folder named "contigs". Contig IDs are labeled based on read file names.

# rename_contigs.sh 
For all .fasta files in a folder, will prefix contigs with respective assembly ID. Usage is sh rename_contigs.sh /path/to/fastas

# prokka.sh
For all .fasta in a folder, will create a new folder "prokka" which has output and locus-tag prefixed by assembly ID. Usage sh prokka.sh /path/to/fastas
If genomes are in .fna, update the script accordingly 

# filter_contigs_length.sh
Removes length of all contigs based on length threshold. Must have bbmap installed to run the script. To change the threshold, update line 13 accordingly. Usage is sh filter_contigs_length.sh /path/to/fastas 
If genomes are in .fna, update the script accordingly




