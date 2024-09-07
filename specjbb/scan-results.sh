
SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

BASE_DIR=${SCRIPTPATH}

export LC_NUMERIC=en_US.UTF-8
export LANG=en_US.UTF-8

# $1 TESTDIR
function post_process_gc_times() {

	local TESTDIR=$1

	local FILE="${TESTDIR}/composite.out"


	# Filter out warmup phase, we only want to examine the explicitly issued full gcs
	#awk "BEGIN {IN=0} /will start GCs\.\.\./ {IN=1} /after GCs\.\.\./ {IN=0} { if (IN==1) print }" < "${FILE}" > outlog-${LETTER}-no-warmup.txt

	# Now scan for GC pauses 
	echo "${TESTDIR} gc times "
	ack '\[gc.*GC\(.*Pause .*ms$' ${FILE} | sed 's/.* \([0-9\.,]*\)ms/\1/g' > gc-times-${TESTDIR}.txt
	datamash --header-out count 1 sum 1 median 1 sstdev 1 < gc-times-${TESTDIR}.txt 


	# Now scan for post-GC liveset sizes
	echo "${TESTDIR} post-gc liveset sizes"
        ack '\[gc.*GC\(.*Pause.*ms$' ${FILE} | sed 's/.*[KMG]->\([0-9][0-9]*\)M([0-9]*.*/\1/g' > gc-liveset-${TESTDIR}.txt
	datamash --header-out count 1 median 1 mean 1 < gc-liveset-${TESTDIR}.txt

}



BASELINE=""

# first positional arg is baseline test dir
for TESTDIR in $*; do
	post_process_gc_times $TESTDIR
	if [[ "$BASELINE" == "" ]]; then
		BASELINE=$TESTDIR
	else
		#Compare GC pause sums to baseline
		OUTFILE_A="gc-times-${BASELINE}.txt"
		OUTFILE_B="gc-times-${TESTDIR}.txt"
		
		A=`datamash sum 1 < $OUTFILE_A`
		B=`datamash sum 1 < $OUTFILE_B`
		B_TO_A=`echo "scale=2; ($B * 100) / $A" | bc`
		echo "GC Times, Sum, $TESTDIR to $BASELINE: $B_TO_A%"

		#Compare Post-GC liveset sizes
		OUTFILE_A="gc-liveset-${BASELINE}.txt"
		OUTFILE_B="gc-liveset-${TESTDIR}.txt"
		
		A=`datamash mean 1 < $OUTFILE_A`
		B=`datamash mean 1 < $OUTFILE_B`
		B_TO_A=`echo "scale=2; ($B * 100) / $A" | bc`
		echo "GC Liveset Sizes, average, $TESTDIR to $BASELINE: $B_TO_A%"
	fi
done


