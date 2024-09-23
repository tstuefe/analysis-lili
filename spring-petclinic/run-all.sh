#!/bin/bash

set -oeu pipefail

export SCRIPTDIR=`realpath "$0" | xargs dirname`

source "${SCRIPTDIR}/common-functions.sh"

exit_if_not_root



echo "PID of $0 : $$"

export PERF_COMMAND="perf stat --no-big-num -e  L1-dcache-load-misses,L1-dcache-loads,LLC-load-misses,LLC-loads,dTLB-load-misses,dTLB-loads,instructions,branches"
#export PERF_COMMAND=" "

NUM_RUNS=4

TESTNAME_BASE="G1-8G"

RESULTDIR="RESULTS"

rename_old_dir_if_needed "$RESULTDIR"

mkdir "$RESULTDIR"
pushd "$RESULTDIR"


export JDK_TO_TEST=`realpath "${SCRIPTDIR}/../jdk-liliput"`
export WHATGC="-XX:+UseG1GC"
export JVM_ARGS_COMMON="-XX:+PrintFlagsFinal -Xshare:off"
export WHAT_MAX_HEAPSIZE="-Xmx8g"

for (( run=0; run < $NUM_RUNS; run++ )); do

export JVM_ARGS="${JVM_ARGS_COMMON} -XX:+UnlockExperimentalVMOptions -XX:+UseCompactObjectHeaders "
export TESTNAME="COH-ON-${TESTNAME_BASE}-${run}"
bash "${SCRIPTDIR}/run-single-test.sh"

export JVM_ARGS="${JVM_ARGS_COMMON} -XX:+UnlockExperimentalVMOptions -XX:-UseCompactObjectHeaders "
export TESTNAME="COH-OFF-${TESTNAME_BASE}-${run}"
bash "${SCRIPTDIR}/run-single-test.sh"

done

popd

chown -R thomas $RESULTDIR

echo "Results in $RESULTDIR"


