#!/bin/bash
#Usage: sh spades.sh <path to input files>


cd $1

for f in *_R1_001.fastq.gz
do
if [ -d "${f%_R1_001.fastq.gz}" ]
then
echo 'skip'${f}
continue
fi
echo 'assemble'${f%_R1_001.fastq.gz}
spades.py --careful -1 $f -2 ${f%_R1_001.fastq.gz}_R2_001.fastq.gz -o ${f%_R1_001.fastq.gz} -t 7 -m 20;
done

mkdir contigs  
for f in *_R1_001.fastq.gz
do
	cd ${f%_R1_001.fastq.gz}
	cat contigs.fasta > ${f%_R1_001.fastq.gz}_contigs.fasta
	cp ${f%_R1_001.fastq.gz}_contigs.fasta ../contigs
	cd ..;
done

mkdir scaffolds  
for f in *_R1_001.fastq.gz
do
	cd ${f%_R1_001.fastq.gz}
	cat scaffolds.fasta > ${f%_R1_001.fastq.gz}_scaffolds.fasta
	cp ${f%_R1_001.fastq.gz}_scaffolds.fasta ../scaffolds
	cd ..;
done
