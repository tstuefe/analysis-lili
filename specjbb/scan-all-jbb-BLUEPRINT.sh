#!/bin/bash

# one stop script to scan all output of a number of specjbb runs
# Copy to result root dir, then adapt

set -euo pipefail

SCRIPTDIR="/shared/projects/openjdk/analysis/liliput-benefits/specjbb"

NAME_A="COH-OFF"
NAME_B="COH-ON"
NAME_C=

DIR_PREFIX_A="results-COH-OFF-"
DIR_PREFIX_B="results-COH-ON-"
DIR_PREFIX_C=

PERF_OUTPUT_FILE="composite.log"
JVM_LOG_OUTPUT_FILE="composite.out"


# scan perf output
# $1 name
# $2 dir prefix
function scan_perf_output () {
	if [ ! -z "$1" -a ! -z "$PERF_OUTPUT_FILE" ]; then
		echo "***${1}***"
		echo
		bash $SCRIPTDIR/scan-perf-values.sh "$1" "${2}*/${PERF_OUTPUT_FILE}"
		echo
	fi
}

# scan jvm metrics
# $1 name
# $2 dir prefix
function scan_jvm_metrics () {
	if [ ! -z "$1" ]; then
		echo "***${1}***"
		echo
		bash $SCRIPTDIR/scan-jvm-metrics.sh "$1" "${2}*/${JVM_LOG_OUTPUT_FILE}"
		echo
	fi
}

# scan jbb results
# $1 name
# $2 dir prefix
function scan_jbb_results () {
	if [ ! -z "$1" ]; then
		echo "***${1}***"
		echo
		bash $SCRIPTDIR/scan-specJBB-results.sh "$1" "${2}*"
		echo
	fi
}

scan_perf_output "$NAME_A" "$DIR_PREFIX_A"
scan_perf_output "$NAME_B" "$DIR_PREFIX_B"
scan_perf_output "$NAME_C" "$DIR_PREFIX_C"

scan_jvm_metrics "$NAME_A" "$DIR_PREFIX_A"
scan_jvm_metrics "$NAME_B" "$DIR_PREFIX_B"
scan_jvm_metrics "$NAME_C" "$DIR_PREFIX_C"

scan_jbb_results "$NAME_A" "$DIR_PREFIX_A"
scan_jbb_results "$NAME_B" "$DIR_PREFIX_B"
scan_jbb_results "$NAME_C" "$DIR_PREFIX_C"

