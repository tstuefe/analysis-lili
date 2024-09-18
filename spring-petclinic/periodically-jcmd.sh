#!/bin/bash

set -eou pipefail

function printUsageAndExit () {
	echo "Usage: 	<period in seconds> <pid>"
	exit -1
}

if [ "$#" -lt 2 ]; then
	printUsageAndExit
fi

PAUSETIME=$1
PID=$2

echo "Started!"
echo "Pid: $PID"
echo "Sleeptime: $PAUSETIME"

while true; do
	if [ ! -d "/proc/$PID" ]; then
		echo "Lost process $PID"
		exit 0
	fi
	sleep $PAUSETIME
	date
	jcmd $PID GC.run
done



