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
      -t <v> : *required* Number of threads to use.
EOF
);


while getopts f:b:o:t: option
do
    case "${option}"
    in
	t) TC=${OPTARG};;
    esac
done


mkdir aligned
mkdir paml

##Align
total=11000
n=1
while [ $n -lt $total ]; do
	i=`ps -all | grep 'java\|codeml' | wc -l`
	if [ $i -lt $TC ] ; #are there less than $TC jobs currently running?
	then
		#echo 'I have a core to use'
		if [ -f ortholog/$n.hits.fa ] ; #does the file exist?
		then
			#echo "The input file om.$i.fa seems to exist"
			if [ ! -f aligned/$n.hits.aln ] ; #have I already done the analyses elsewhere?
			then
				java -Xmx1000m -jar /share/bin/macse_v1.01b.jar -prog alignSequences -seq ortholog/$n.hits.fa -out_NT aligned/$n.hits.aln & #just do it!   	
				wait %%
				sed -i 's_!_-_g' aligned/$n.hits.aln
				sed -i "s/ENS.*/mus/g" aligned/$n.hits.aln
				sed -i "s/gi.*/pema/g" aligned/$n.hits.aln
				sed -i "s/[0-9].*/peer/g" aligned/$n.hits.aln
				python $HOME/pero_transcriptome/fa2phy.py aligned/$n.hits.aln aligned/$n.hits.phy
				sed -i "s_seqfile =.*_seqfile = aligned/${n}.hits.phy_g" codeml.ctl
				sed -i "s_outfile =.*_outfile = paml/${n}.hits.out_g" codeml.ctl
				yes "\n" | codeml &
				let n=n+1
			else
				if [ ! -f omega/om.$n.aln.out ] ; #have I already done the analyses elsewhere?
				then
					#echo 'I need to run PAML'
					sed -i "s_seqfile =.*_seqfile = aligned/${n}.hits.phy" codeml.ctl
					sed -i "s_outfile =.*_outfile = aligned/${n}.hits.out" codeml.ctl
					yes "\n" | codeml &
					let n=n+1
				else
					#echo "Sweet! I already ran PAML"
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

