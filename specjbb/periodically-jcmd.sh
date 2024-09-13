#!/bin/bash

set -eou pipefail

function printUsageAndExit () {
	echo "Usage: 	$0 <period in seconds> <pid or app name> <command>"
	echo "Example:  $0 120 eclipse VM.metaspace show-loaders"
	echo "Example:  $0 120 eclipse VM.metaspace show-loaders"
	
	exit -1
}

if [ "$#" -lt 2 ]; then
	printUsageAndExit
fi

PAUSETIME=$1
TARGET=$2
shift
shift

COMMAND=$*

OUTFILE=jcmd-out.txt

echo "Started!" > "$OUTFILE"
echo "Target: $TARGET" >> "$OUTFILE"
echo "Command: $COMMAND" >> "$OUTFILE"
echo "Sleeptime: $PAUSETIME" >> "$OUTFILE"


while true; do
	date >> "$OUTFILE"
	jcmd $TARGET $COMMAND >> "$OUTFILE" 2>&1
	sleep $PAUSETIME
done



