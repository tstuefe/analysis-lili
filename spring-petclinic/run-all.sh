#!/bin/bash

SCRIPTDIR=`realpath "$0" | xargs dirname`

source "${SCRIPTDIR}/common-functions.sh"

exit_if_not_root


JDK_TO_TEST=`realpath "${PWD}/../jdk-liliput"`

echo "PID of $0 : $$"

export PERF_COMMAND="perf stat --no-big-num -e  L1-dcache-load-misses,L1-dcache-loads,LLC-load-misses,LLC-loads,dTLB-load-misses,dTLB-loads,instructions,branches"
#export PERF_COMMAND=" "

NUM_RUNS=4

TESTNAME_BASE="G1-8G"

BASEDIR="RESULTS"

rename_old_dir_if_needed "$BASEDIR"

mkdir "$BASEDIR"
pushd "$BASEDIR"

exit 0


export WHATGC="-XX:+UseG1GC"
export JVM_ARGS_COMMON="-XX:+PrintFlagsFinal -Xshare:off"
export WHAT_MAX_HEAPSIZE="-Xmx8g"

for (( run=0; run < $NUM_RUNS; run++ )); do

export JDK=$JDK_TO_TEST
export JVM_ARGS="${JVM_ARGS_COMMON} -XX:+UnlockExperimentalVMOptions -XX:+UseCompactObjectHeaders "
export TESTNAME="COH-ON-${TESTNAME_BASE}-${run}"
bash ./run-single-test.sh

export JDK=$JDK_TO_TEST
export JVM_ARGS="${JVM_ARGS_COMMON} -XX:+UnlockExperimentalVMOptions -XX:-UseCompactObjectHeaders "
export TESTNAME="COH-OFF-${TESTNAME_BASE}-${run}"
bash ./run-single-test.sh

done

popd

echo "Results in $BASEDIR"
