#! /bin/bash

######Requirements
#MACse, omegaMap

#Need to specify bam folder
#Need to give trinity.fasta file


usage=$(cat << EOF
   # This script runs a pipeline that takes a fasta file and BAMfiles and tests for selection:
   #   
   
   omegav3.sh [options]

   Options:
      -f <v> : *required* specify the FASTA file.
      -o <v> : *required* omegaMap control file.
      -t <v> : *required* Numberof threads to use.
EOF
);


while getopts f:b:o:t: option
do
    case "${option}"
    in
    f) FA=${OPTARG};;
	o) CF=${OPTARG};;
	t) TC=${OPTARG};;
    esac
done

#MACSE = which macse_v1.01b.jar

##cluster seqs
#mkdir unalign
#mkdir aligned
mkdir omega
#grep '>'  $FA | awk '{print $1}' | sed 's_>__g' > list ##Change this to $fasta when I know how--DONE
#for i in `cat list`; do grep -h --max-count=1 --no-group-separator -wA1 $i 3*fasta > unalign/om.$i.fa; done 
#for i in `ls unalign/om*fa`; do sed -i 's_R_A_g;s_Y_G_g;s_W_A_g;s_S_C_g;s_M_A_g;s_K_C_g' $i; done
#rm list

##Align
total=50000
n=1
while [ $n -lt $total ]; do
	i=`ps -all | grep 'java\|omegaMap' | wc -l`
	if [ $i -lt $TC ] ; #are there less than $TC jobs currently running?
	then
		#echo 'I have a core to use'
		if [ -f unalign/om.$n.fa ] ; #does the file exist?
		then
			#echo "The input file om.$i.fa seems to exist"
			if [ ! -f aligned/om.$n.aln ] ; #have I already done the analyses elsewhere?
			then
				#echo 'I need to do the analysis'
				var1=$(grep -o 'N\|-' unalign/om.$n.fa | wc -l)
				var2=$(wc -m unalign/om.$n.fa | awk '{print $1}')
				var3=$(awk -v VAR1=$var1 -v VAR2=$var2 'BEGIN {print VAR1/VAR2}')
				var4=$(awk -v VAR3=$var3 'BEGIN {if (VAR3<.01) print "smaller"; else print "bigger";}')
				if [ $var4 = smaller ] ;
				then
					java -Xmx1000m -jar /share/bin/macse_v1.01b.jar -prog alignSequences -seq unalign/om.$n.fa -out_NT aligned/om.$n.aln #just do it!   	
					sed -i ':begin;$!N;/[ACTG]\n[ACTG]/s/\n//;tbegin;P;D' aligned/om.$n.aln
					sed -i 's_TAG$_GGG_g;s_TGA$_GGG_g;s_TAA$_GGG_g;s_N_-_g;s_!_-_g' aligned/om.$n.aln
					export var5=$(sed -n '2p' aligned/om.$n.aln)
					export var6=$(sed -n '4p' aligned/om.$n.aln)
					var7=$(python $HOME/pero_transcriptome/hamming1.py)
					if [ $var7 -gt 0 ] && [ $var7 -lt 50 ] ;
					then
						echo "HAMMING distanse is $var7"
						omegaMap $CF -outfile omega/om.$n.aln.out -fasta aligned/om.$n.aln &
						let n=n+1
					else
						echo "HAMMING distanse is TOO BIG OR SMALL $var7"
						let n=n+1
					fi
				else
					echo "TOO MANY N's $var3"
					let n=n+1
				fi
			else
				if [ ! -f omega/om.$n.aln.out ] ; #have I already done the analyses elsewhere?
				then
					#echo 'I need to do the analysis'
					sed -i ':begin;$!N;/[ACTG]\n[ACTG]/s/\n//;tbegin;P;D' aligned/om.$n.aln
					sed -i 's_TAG$_GGG_g;s_TGA$_GGG_g;s_TAA$_GGG_g;s_N_-_g;s_!_-_g' aligned/om.$n.aln
					export var8=$(sed -n '2p' aligned/om.$n.aln)
					export var9=$(sed -n '4p' aligned/om.$n.aln)
					var10=$(python $HOME/pero_transcriptome/hamming2.py)
					if [ $var10 -gt 0 ] && [ $var10 -lt 50 ];
						then
						echo "HAMMING distanse is $var10"
						omegaMap $CF -outfile omega/om.$n.aln.out -fasta aligned/om.$n.aln & #just do it!
						let n=n+1
					else
						echo "HAMMING distanse is TOO BIG OR SMALL $var10"        
						let n=n+1
					fi
			else
				#echo "Sweet! I already made om.m.$n.aln.out!"
				let n=n+1
				fi
			fi
		else
			let n=n+1
			#echo "I'm up to $n"
		fi
	else
		echo 'Dont wake me up until there is something else to do'
		sleep 15s #there are already $TC jobs-- you can take a rest now...
	fi
done
wait

for i in `ls omega/om*out`; do summarize 2000 $i > omega/$i.results; done

##Process Results
rm summary.file names.fa
for i in `ls omega/om*results`; do sed -n '4p' $i >> summary.file; done
for i in `ls omega/om*results`; do F=`basename $i .out.results`; echo $F >> names.fa; done; paste names.fa summary.file > selection.txt
cat selection.txt |  awk '0.00015<$6{next}1' | awk '{print $1 "\t" $4 "\t" $6}' > positive.selection
cat selection.txt |  awk '0.01<$6{next}1' | awk '{print $1}' | grep -wEo -A1  m.[[:digit:]]\{1,} | grep -w -A1 --no-group-separator -f - $FA > sig.selection.fa
cat selection.txt |  awk '0.00015<$6{next}1' | awk '{print $1}' | grep -wEo -A1  m.[[:digit:]]\{1,} | grep -w -A1 --no-group-separator -f - ../aas.pep > sig.selection.pep
