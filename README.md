Useful Scripts for Bioinformatic Analyses

# spades.sh 
Script is comptabile with SPAdes genome assembler v3.15.5. Usage is sh spades.sh /path/to/paired/reads
If reads do not end in R1_001 or R2_001, update script accordingly. Assemblies will be put in a folder named "contigs". Assembly IDs are labeled based on read file names.

# rename_contigs.sh 
For all .fasta files in a folder, will prefix lines that start with ">" (aka contigs) with respective assembly ID. Usage is sh rename_contigs.sh /path/to/fastas

# prokka.sh
For all .fasta in a folder, will create a new folder "prokka" which has output and locus-tag prefixed by assembly ID. Usage sh prokka.sh /path/to/fastas
If genomes are in .fna, update the script accordingly 

# filter_contigs_length.sh
Removes length of all contigs based on length threshold. Must have bbmap installed via conda to run the script. To change the threshold, update line 13 accordingly. Usage is sh filter_contigs_length.sh /path/to/fastas 
If genomes are in .fna, update the script accordingly

# amrfinder.sh
Runs amrfinder on all assemblies in a folder. Script is made to use E. faecium chromosomal database. Update -O flag based on species, or remove the flag if no database exists (line 17). Usage is sh amrfinder.sh path/to/fastas.
If genomes are in .fna, update the script accordingly 

# combined_contigs.sh
Combined all contigs in a assembly file, specifically a .fna, into 1 contig. If your assemblies end in .fasta or another extention please edit the script accordingly. 




