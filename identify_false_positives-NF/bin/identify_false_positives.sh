
# Enable bash debugging to log all commands
set -x

echo "Job running on: `hostname`"

CAMO_ANNOTATION=$1
INCLUDE_REGIONS=$2
MASK_BED=$3
REF=$4
NUM_THREADS=$5

query="./query/mapq_genes.query.fa"
blat_result="./blat_result/blat.results.psl"
blat_log="./blat_log/tmp.blat.log"
blat_bed=${blat_result//psl/bed}
false_positives="false_positives.txt"

################################################
# Create BLAT queries from camouflaged regions #
################################################

mkdir -p "query"
if [[ "${INCLUDE_REGIONS,,}" == "cds" ]]; then

	# Only awk out CDS regions (i.e., only include CDS)
	if ! grep -vE "^#" $CAMO_ANNOTATION | \
		awk '$5 == "CDS"' | \
		bedtools intersect \
			-a - \
			-b $MASK_BED \
			-wb | \
			awk '$NF <= 5' | \
			bedtools getfasta \
				-fi $REF \
				-bed - \
				-name+ \
				-fo $query; then
		echo "`date` bedtools intersect failed for $CAMO_ANNOTATION and $MASK_BED"
		exit 1
	fi
else

	# Do NOT awk out CDS regions (i.e., use all)
	if ! grep -vE "^#" $CAMO_ANNOTATION | \
		bedtools intersect \
			-a - \
			-b $MASK_BED \
			-wb | \
			awk '$NF <= 5' | \
			bedtools getfasta \
				-fi $REF \
				-bed - \
				-name+ \
				-fo $query; then
		echo "`date` bedtools intersect failed for $CAMO_ANNOTATION and $MASK_BED"
		exit 1
	fi
fi

nLines=$(wc -l $query | awk '{print $1}')
stepSize=$(($nLines / $NUM_THREADS))
if [[ $(($stepSize % 2 )) == 1 ]]
then
	    stepSize=$(($stepSize + 1))
fi

rm -rf "./blat_result"
mkdir -p "./blat_result"
mkdir -p "./blat_log"
pid_array=()
for i in $(seq 1 $stepSize $nLines)
do
	sed "$((i)),$((i + $stepSize - 1))!d" $query > ${query}.${i}
	blat $REF ${query}.${i} \
			-t=dna \
			-q=dna \
			-minIdentity=95 \
			-noHead \
			${blat_result}.${i} \
			&> ${blat_log}.${i} &

	# Save PID for each submitted background process. "$!" always
    # holds the PID for most recently submitted process.
    pid_array+=($!)

done


# Wait until all submitted processes are completed.
keep_waiting=true
while $keep_waiting
do
    keep_waiting=false
    for pid in "${pid_array[@]}"
    do
        if ps -p $pid > /dev/null; then

            # At least this process is still running, so keep waiting
            keep_waiting=true
            echo "(`date`) Waiting on blat (PID: $pid)..."
        fi
    done

    # sleep for 10 seconds
    sleep 10
done


echo "`date` blatting complete: combining blat output"
cat ${blat_result}.* > $blat_result

echo "`date` scoring blat output"
# filter all sequences with sequence identity >= 98%
if ! score_blat_output.awk \
	$blat_result \
	> $blat_bed; then
	echo "`date` score_blat_output.awk failed for $blat_result."
	exit 1
fi

