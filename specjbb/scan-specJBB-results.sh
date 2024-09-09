#!/bin/bash

set -euo pipefail

function print_usage_and_exit () {
	echo "Usage: $0 <prefix> <specJBB result dir> [<result dir> ...]"
	echo "e.g. $0 COH-OFF results-COH-OFF*"
	exit -1
}

if [[ "$#" -lt 2 ]]; then
	print_usage_and_exit
fi

PREFIX=$1

# prevent stupid  errors
if [ -d $1 -o -f $1 ]; then
	echo "First argument, $1, is an existing directory or file."
	print_usage_and_exit;
fi

resultfile="${PREFIX}-jOPS.csv"

if [ -f "$resultfile" ]; then
	rm "$resultfile"
fi

shift

RUN=0

# $1 what
# $2 100% value
function printperc () {
	echo "scale=2; (($1 * 100.0) / $2)" | bc
}

echo "run,maxjops,critjops," > "$resultfile"

for DIR in $*; do
	echo "Processing $DIR ..."
	
	if [ ! -d $DIR ]; then
		echo "$DIR does not exist or is not a file"
		exit -1
	fi

	line=`ack 'RESULT.*max-jOPS.*critical-jOPS' "${DIR}/composite.out"`
	echo $line
	maxjops=`echo "${line}" | sed 's/.*max-jOPS = \([0-9][0-9]*\),.*/\1/g'`
	critjops=`echo "${line}" | sed 's/.*critical-jOPS = \([0-9][0-9]*\).*/\1/g'`
	echo "max: $maxjops crit: $critjops"
	
	echo "${RUN},${maxjops},${critjops}," >> "$resultfile"

	RUN=$(( RUN + 1 ))
done

export LC_NUMERIC=en_US.UTF-8

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

print_mean_and_sstdev "Max jOPS          :" 2
print_mean_and_sstdev "Critical jOPS     :" 3

