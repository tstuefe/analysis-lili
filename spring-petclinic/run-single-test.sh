# !/bin/bash

set -oeu pipefail

SCRIPTDIR=`realpath "$0" | xargs dirname`

source "${SCRIPTDIR}/common-functions.sh"

############# Initial tests ########################################

exit_if_not_root

exit_if_machine_is_not_stabilized_for_benchmarks

exit_if_port_is_occupied "8080"


#### parameters

# Test ID
TESTNAME_DEFAULT="KANNWEG"
TESTNAME=${TESTNAME:-$TESTNAME_DEFAULT}

# The JDK we test
JDK_TO_TEST_DEFAULT="I-DONT-KNOW"
JDK_TO_TEST="${JDK_TO_TEST:-$JDK_TO_TEST_DEFAULT}"

WHATGC_DEFAULT="-XX:+UseG1GC"
WHATGC=${WHATGC:-$WHATGC_DEFAULT}

WHAT_MAX_HEAPSIZE_DEFAULT="-Xmx6g"
WHAT_MAX_HEAPSIZE=${WHAT_MAX_HEAPSIZE:-$WHAT_MAX_HEAPSIZE_DEFAULT}

# Perf command line; leave empty for no perf
# Example: PERF_COMMAND="perf stat --no-big-num -e L1-dcache-load-misses,L1-dcache-loads,LLC-load-misses,LLC-loads,dTLB-load-misses,dTLB-loads,instructions,branches"
PERF_COMMAND_DEFAULT=""
PERF_COMMAND=${PERF_COMMAND:-$PERF_COMMAND_DEFAULT}


# Additional jvm args
JVM_ARGS_DEFAULT=""
JVM_ARGS=${JVM_ARGS:-$JVM_ARGS_DEFAULT}

# if we trigger full gcs from outside periodically, the period, in seconds.
# Leave "" if not
FULL_GC_PERIOD_DEFAULT=""
FULL_GC_PERIOD=${FULL_GC_PERIOD:-$FULL_GC_PERIOD_DEFAULT}

# The jmeter script name
JMETER_SCRIPT="${SCRIPTDIR}/petclinic_test_plan-short.jmx"

# Number of seconds we wait for spring petclinic to finish startup
STARTUPTIME=10

########## Prepare test dir #########################################

RESULTDIR="./results-${TESTNAME}"

create_dir_delete_old "${RESULTDIR}"

pushd "$RESULTDIR"

# contains all executed commands
COMMANDS_LOG="./commands.log"

########## Fork off Spring, perf (if needed) and the periodic jcmd
##########    runner (if needed) ###################################

echo "PID of start script $0 : $$"

# Fork off spring
# We run spring on CPUs 0..11
TASKSET_SPRING="0xFFF"
GCLOG="-Xlog:gc* -Xlog:metaspace*"
COMMAND="chrt -r 1 taskset ${TASKSET_SPRING} ${JDK_TO_TEST}/bin/java $WHATGC $WHAT_MAX_HEAPSIZE $JVM_ARGS $GCLOG -jar ${SCRIPTDIR}/spring-petclinic-2.5.0-SNAPSHOT.jar"
start_process "$COMMAND" "spring-petclinic"
SPRING_PID=$PID
echo "PID of spring process: $SPRING_PID"

# Fork off perf
if [ "$PERF_COMMAND" != "" ]; then
	COMMAND="$PERF_COMMAND -p ${SPRING_PID}"
	start_process "$COMMAND" "perf"
        PERF_PID=$PID
	echo "PID of perf process: $PERF_PID"
fi

# Fork off jcmd for periodic full gc
if [ "$FULL_GC_PERIOD" != "" ]; then
	COMMAND="bash ${SCRIPTDIR}/periodically-jcmd.sh ${FULL_GC_PERIOD} ${SPRING_PID}"
	start_process "$COMMAND" "jcmd"
	JCMD_PID=$PID
	echo "PID of jcmd script: $JCMD_PID"
fi

# wait until startup completed
sleep ${STARTUPTIME} 

# Sanity checks: All processes  should still be up

exit_if_process_not_found $SPRING_PID "spring petclinic"
if [ "$FULL_GC_PERIOD" != "" ]; then
	exit_if_process_not_found $JCMD_PID "jcmd looper"
fi
if [ "$PERF_COMMAND" != "" ]; then
	exit_if_process_not_found $PERF_PID "perf monitor"
fi

########## Start jmeter and wait until its finished ###################################

JMETER_OPTIONS="-H localhost -P 8080 -t ${JMETER_SCRIPT} -n -e -l ./jmeter.jtl -o ./jmeter-report"

# We run jmeter on CPUs 12..15
TASKSET_JMETER="0xF000"
COMMAND="chrt -r 1 taskset ${TASKSET_JMETER} ${JDK_TO_TEST}/bin/java -jar ${SCRIPTDIR}/apache-jmeter-5.6.3/bin/ApacheJMeter.jar ${JMETER_OPTIONS}"
start_process "$COMMAND" "jmeter"
JMETER_PID=$PID
echo "PID of jmeter process: $JMETER_PID"

# wait wait wait wait wait
echo "Waiting for jmeter to finish..."
wait_for_process_to_finish "$JMETER_PID"

# stop spring 

# this should also kill perf and jcmd if they are running, but to be sure we kill them manually further down
# (and hope pids did not get reused in that time)
echo "Stopping Spring and dependend processes..."
kill_process $SPRING_PID

if [ ! -z "${JCMD_PID:-}" ]; then
	kill_process $JCMD_PID
fi

if [ ! -z "${PERF_PID:-}" ]; then
	kill_process $PERF_PID
fi

sleep 2

popd

chown -R thomas .

echo "Done."


