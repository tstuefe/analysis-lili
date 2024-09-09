#!/bin/bash

set -e

if [[ "$#" -lt 2 ]]; then
	echo "Usage: $0 <prefix> <specJBB result dir> [<result dir> ...]"
	echo "e.g. $0 COH-OFF results-COH-OFF*"
	exit -1
fi

PREFIX=$1

resultfile="${PREFIX}-jOPS.csv"

if [ -f "$resultfile" ]; then
	rm "$resultfile"
fi

shift

RUN=0

echo "run,maxjops,critjops," > "$resultfile"

for DIR in $*; do
	echo "Processing $DIR ..."
	
	line=`ack 'RESULT.*max-jOPS.*critical-jOPS' "${DIR}/composite.out"`
	echo $line
	maxjops=`echo "${line}" | sed 's/.*max-jOPS = \([0-9][0-9]*\),.*/\1/g'`
	critjops=`echo "${line}" | sed 's/.*critical-jOPS = \([0-9][0-9]*\).*/\1/g'`
	echo "max: $maxjops crit: $critjops"
	
	echo "${RUN},${maxjops},${critjops}," >> "$resultfile"

	RUN=$(( RUN + 1 ))
done

export LC_NUMERIC=en_US.UTF-8

# Not sure why, but the -t option in datamash never seems to work. Translate commas to tabs before invoking datamash,
maxjops_mean=`tr ',' '\t' < "${resultfile}" | datamash --header-in mean 2`
maxjops_sstdev=`tr ',' '\t' < "${resultfile}" | datamash --header-in sstdev 2`
maxjops_sstdev_perc=`echo "scale=2; (${maxjops_sstdev} * 100.0) / ${maxjops_mean}" | bc`

critjops_mean=`tr ',' '\t' < "${resultfile}" | datamash --header-in mean 3`
critjops_sstdev=`tr ',' '\t' < "${resultfile}" | datamash --header-in sstdev 3`
critjops_sstdev_perc=`echo "scale=2; (${critjops_sstdev} * 100.0) / ${critjops_mean}" | bc`

count=`tr ',' '\t' < "${resultfile}" | datamash --header-in count 1`

echo
echo
echo "** results of $count runs: **"
echo
cat "$resultfile"

echo
echo "maxjops mean:    $maxjops_mean"
echo "maxjops sstdev:  $maxjops_sstdev ($maxjops_sstdev_perc%)"
echo "critjops mean:   $critjops_mean"
echo "critjops sstdev: $critjops_sstdev ($critjops_sstdev_perc%)"

