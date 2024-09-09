#!/bin/bash

# Given a set of result directories, for each director, scans the output file
# for JVM metrics:
# - GC log messages, liveset size after GC
# - GC log messages, gc pause times
#
# Then it generates an result file called <prefix>-jvm-metrics.csv containing
# the accumulated values (sum gc pause times and mean liveset size)
#
# Note: creates a temporary directory called <prefix>-temp for temp data

set -e

if [[ "$#" -lt 2 ]]; then
	echo "Usage: $0 <prefix> <specJBB result dir> [<result dir> ...]"
	echo "e.g. $0 COH-OFF results-COH-OFF*"
	exit -1
fi

PREFIX=$1

resultfile="${PREFIX}-jvm-metrics.csv"

if [ -f "$resultfile" ]; then
	rm "$resultfile"
fi

tempdir="${PREFIX}-temp-jvmmetrics"

if [ -d "$tempdir" ]; then
	rm -rf "$tempdir"
fi
mkdir "$tempdir"

shift


export LC_NUMERIC=en_US.UTF-8
export LANG=en_US.UTF-8


# $1 what
# $2 100% value
function printperc () {
	echo "scale=2; (($1 * 100.0) / $2)" | bc
}

function ms2sec () {
	echo "scale=3; $1 / 1000.0" | bc
}

# run: run number
# gc-count: 	number of GCs
# usage-pre:    MB used before GC
# usage-post:   MB used post GC (liveset size)
# pause:        sum of all pauses, in seconds
# real:         sum of real, in seconds (should correspond closely to pause)
# user:         sum user time, in seconds
# sys:          sum sys time, in seconds

echo "run,gc-count,usage-pre,usage-post,pause,real,user,sys" > "${resultfile}"

RUN=0

# first positional arg is baseline test dir
for TESTDIR in $*; do

	echo "Processing $TESTDIR ..."

	COMPOSITE_FILE="${TESTDIR}/composite.out"

	# Filter out warmup phase, we only want to examine the explicitly issued full gcs
	#awk "BEGIN {IN=0} /will start GCs\.\.\./ {IN=1} /after GCs\.\.\./ {IN=0} { if (IN==1) print }" < "${FILE}" > outlog-${LETTER}-no-warmup.txt


	# Now scan for GC pauses 
	tmpf="${tempdir}/gc-times-${TESTDIR}.txt"
	ack '\[gc.*GC\(.*Pause .*ms$' ${COMPOSITE_FILE} | sed 's/.* \([0-9\.,]*\)ms/\1/g' > "$tmpf"
#	datamash -H count 1 sum 1 median 1 sstdev 1 < gc-times-${TESTDIR}.txt 
	gc_count=`datamash --header-in count 1 < ${tmpf}`
	gc_pauses_sum=`datamash --header-in --round=1 sum 1 < ${tmpf}`
        gc_pauses_sum=`ms2sec $gc_pauses_sum`	

	# Now scan for 
	# [8042.898s][info][gc,cpu         ] GC(4330) User=0.61s Sys=0.00s Real=0.11s
	# and give us accumulated CPU time (User+Sys) and Real time (Real) - note that the latter should correspond with the GC pause time (should it??)
	tmpf="${tempdir}/gc-user-${TESTDIR}.txt"
        ack '\[gc.*GC\(.*User.*Sys.*Real' ${COMPOSITE_FILE} | sed 's/.*User=\([0-9.]*\)s.*/\1/g' > "$tmpf"
	gc_user_sum=`datamash --header-in sum 1 < ${tmpf}`

	tmpf="${tempdir}/gc-sys-${TESTDIR}.txt"
        ack '\[gc.*GC\(.*User.*Sys.*Real' ${COMPOSITE_FILE} | sed 's/.*Sys=\([0-9.]*\)s.*/\1/g' > "$tmpf"
	gc_sys_sum=`datamash --header-in sum 1 < ${tmpf}`

	tmpf="${tempdir}/gc-real-${TESTDIR}.txt"
        ack '\[gc.*GC\(.*User.*Sys.*Real' ${COMPOSITE_FILE} | sed 's/.*Real=\([0-9.]*\)s.*/\1/g' > "$tmpf"
	gc_real_sum=`datamash --header-in sum 1 < ${tmpf}`

	# Now scan for post-GC liveset sizes
	tmpf="${tempdir}/gc-usage-post-${TESTDIR}.txt"
        ack '\[gc.*GC\(.*Pause.*ms$' ${COMPOSITE_FILE} | sed 's/.*[M]->\([0-9][0-9]*\)M([0-9]*.*/\1/g' > "$tmpf"
#	datamash -H count 1 median 1 mean 1 < gc-liveset-${TESTDIR}.txt
	usage_post_mean=`datamash --header-in --round=1 mean 1 < ${tmpf}`

	# Now scan for pre-GC heap usage
	# eg "70973:[8066.355s][info][gc             ] GC(4349) Pause Young (Prepare Mixed) (G1 Evacuation Pause) 2092M->1756M(4096M) 109.181ms"
	tmpf="${tempdir}/gc-usage-pre-${TESTDIR}.txt"
        ack '\[gc.*GC\(.*Pause.*ms$' ${COMPOSITE_FILE} | sed 's/.* \([0-9][0-9]*\)M->[0-9]*.*/\1/g' > "$tmpf"
#	datamash -H count 1 median 1 mean 1 < gc-liveset-${TESTDIR}.txt
	usage_pre_mean=`datamash --header-in --round=1 mean 1 < ${tmpf}`

	# debug output
#	echo "Num GCs: $gc_counts, GC pauses sum (s): $gc_pauses_sum, User (s): $gc_user_sum, Sys (s): $gc_sys_sum, Real (s): $gc_real_sum, mean Liveset size post gc (M) $usage_post_mean, mean heap usage pre gc: $usage_pre_mean"

	echo "${RUN},${gc_count},${usage_pre_mean},${usage_post_mean},${gc_pauses_sum},${gc_real_sum},${gc_user_sum},${gc_sys_sum}" >> "$resultfile"

	RUN=$(( RUN+1 ))

done


# $1 what
# $2 column number in result file
function print_mean_and_sstdev () {
	local mean=$(tr ',' '\t' < "$resultfile" | datamash --header-in mean $2)
	local sstdev=$(tr ',' '\t' < "$resultfile" | datamash --header-in --round=1 sstdev $2)
	local sstdev_perc=$(printperc $sstdev $mean)
	echo "$1 ${mean} (sstdev ${sstdev}, (${sstdev_perc}%)"
}

echo
echo
echo "*** results of $RUN runs: ***"
echo
cat "$resultfile"

echo
echo "*** Mean values and deviations for $RUN runs: ***"

print_mean_and_sstdev "Number of GCs:            :" 2
print_mean_and_sstdev "Usage before GC (MB)      :" 3
print_mean_and_sstdev "Usage after GC (MB)       :" 4
print_mean_and_sstdev "Sum pause times (seconds) :" 5
print_mean_and_sstdev "Sum GC Real (seconds)     :" 6
print_mean_and_sstdev "Sum GC User (seconds)     :" 7
print_mean_and_sstdev "Sum GC Sys (seconds)      :" 8





