#!/bin/bash

# - given a set of result files, scans them for perf stat output
# - builds an accumulated csv file for all results
# - prints mean and sstdev values for all results
#
# Note: creates a temporary directory called <prefix>-temp for temp data

set -euo pipefail

function print_usage_and_exit () {
	echo "Usage: $0 <prefix> <file> [<file> ...]"
	echo "e.g. $0 COH-OFF results-COH-OFF*-with-perf/composite.out"
	exit -1
}

if [[ "$#" -lt 2 ]]; then
	print_usage_and_exit
fi

PREFIX=$1

# prevent stupid  errors
if [ -d "$1" -o -f "$1" ]; then
	echo "First argument, $1, is an existing directory or file."
	print_usage_and_exit;
fi

resultfile="${PREFIX}-perf-stat-results.csv"

if [ -f "$resultfile" ]; then
	rm "$resultfile"
fi

shift


# $1 what
# $2 100% value
function printperc () {
	echo "scale=2; (($1 * 100.0) / $2)" | bc
}

# run: run number
# gc-count: 	number of GCs
# usage-pre:    MB used before GC
# usage-post:   MB used post GC (liveset size)
# pause:        sum of all pauses, in seconds
# real:         sum of real, in seconds (should correspond closely to pause)
# user:         sum user time, in seconds
# sys:          sum sys time, in seconds

echo "run,l1-misses,l1-loads,llc-misses,llc-loads,tlb-misses,tlb-loads,instructions,branches," > "${resultfile}"

LC_NUMERIC=en_US.UTF-8


# $1 file
# $2 value, e.g. "L1-dcache-load-misses"
function scan_counter() {
	# Example:
	#  1,332,433,689,422      L1-dcache-load-misses            #    5.07% of all L1-dcache accesses   (41.55%)
	# 26,304,006,235,557      L1-dcache-loads                                                         (32.77%)
	#    271,731,406,004      LLC-load-misses                  #   40.63% of all LL-cache accesses    (29.11%)
	#    668,776,912,228      LLC-loads                                                               (28.80%)
	#     38,876,753,367      dTLB-load-misses                 #    0.15% of all dTLB cache accesses  (34.68%)
	# 26,095,345,111,884      dTLB-loads                                                              (29.24%)
	# 86,714,552,890,269      instructions                                                            (41.74%)
	# 16,273,531,040,734      branches                                                                (42.19%)

	# Note: perf may or may not have been started with --no-bignum
        # we weed out thousand separators from count value
	cat "$1" | grep "$2" | sed 's/^ *\([0-9][0-9,]*\).*/\1/g' | tr -d ',' | tr -d '.' 
}

RUN=0

for FILE in $*; do

	echo "Processing $FILE ..."

	if [ ! -f $FILE ]; then
		echo "$FILE does not exist or is not a file"
		exit -1
	fi

	if ! grep -q "Performance counter stats" "$FILE" ; then
		echo "No performance counter stats found in $FILE; skipping perf result scan"
		exit 0
	fi

	l1_misses=$(scan_counter "$FILE" "L1-dcache-load-misses")
	l1_loads=$(scan_counter "$FILE" "L1-dcache-loads")
	llc_misses=$(scan_counter "$FILE" "LLC-load-misses")
	llc_loads=$(scan_counter "$FILE" "LLC-loads")
	tlb_misses=$(scan_counter "$FILE" "dTLB-load-misses")
	tlb_loads=$(scan_counter "$FILE" "dTLB-loads")
	instructions=$(scan_counter "$FILE" "instructions")
	branches=$(scan_counter "$FILE" "branches")

	echo "${RUN},${l1_misses},${l1_loads},${llc_misses},${llc_loads},${tlb_misses},${tlb_loads},${instructions},${branches}," >> "$resultfile"

	RUN=$(( RUN+1 ))
done

# $1 what
# $2 column number in result file
function print_mean_and_sstdev () {
	local mean=$(tr ',' '\t' < "$resultfile" | datamash --round=1 --header-in mean $2)
	local sstdev=$(tr ',' '\t' < "$resultfile" | datamash --header-in --round=1 sstdev $2)
	local sstdev_perc=$(printperc $sstdev $mean)
	echo "$1 ${mean} 	(sstdev ${sstdev}, (${sstdev_perc}%)"
}

echo
echo
echo "*** results of $RUN runs: ***"
echo
echo '```'
cat "$resultfile"
echo '```'

echo
echo "*** Mean values and deviations for $RUN runs: ***"

print_mean_and_sstdev "L1-dcache-load-misses     :" 2
print_mean_and_sstdev "L1-dcache-loads           :" 3
print_mean_and_sstdev "LLC-load-misses           :" 4
print_mean_and_sstdev "LLC-loads                 :" 5
print_mean_and_sstdev "dTLB-load-misses          :" 6
print_mean_and_sstdev "dTLB-loads                :" 7
print_mean_and_sstdev "instructions              :" 8
print_mean_and_sstdev "branches                  :" 9




