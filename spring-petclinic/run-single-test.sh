# !/bin/bash

set -oeu pipefail

# $1 pid
# $2 name
function exit_if_process_not_found () {
	if [ ! -d "/proc/$1" ]; then
		echo "Process not found ($1 $2)"
		exit -1
	fi
}

function kill_process () {
	if [ -d "/proc/$1" ]; then
		echo "Killing $1 (SIGTERM)"
		kill -term $1
		sleep 2 
		if [ -d "/proc/$1" ]; then
			echo "Killing $1 (SIGKILL)"
			kill -9 $1
			if [ -d "/proc/$1" ]; then
				echo "**** $1 is unkillable!"
			fi
		fi
	fi

}

# Start command $1
# Basename for log $2
function start_process () {
	echo "Calling $1" >> $COMMANDS_LOG
	$1 > "${DIR}/${2}.out" 2> "${DIR}/${2}.err" &
	PID=$!
} 

##### parameters

# Test ID
TESTNAME_DEFAULT="KANNWEG"
TESTNAME=${TESTNAME:-$TESTNAME_DEFAULT}

# The JDK we test
JDK_TO_TEST_DEFAULT="${PWD}/../jdk-liliput"
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
#JMETER_SCRIPT="./petclinic_test_plan-300secs.jmx"
JMETER_SCRIPT="./petclinic_test_plan-short.jmx"

# Number of seconds we wait for spring petclinic to finish startup
STARTUPTIME=10


############# Initial tests ########################################

if [ `id -u` -ne 0 ] 
  then echo Please run this script as root or using sudo!
  exit -1
fi

if [[ `sysctl kernel.randomize_va_space` != "kernel.randomize_va_space = 0" ]]; then
        echo "stabilize machine for benchmark!";
	exit -1
fi

# we expect to have CPUs 1-16 isolated
for KERNELPARAM in "isolcpus=0-15" "nohz_full=0-15"; do
	if [ "`cat /proc/cmdline | grep $KERNELPARAM`" == "" ]; then
		echo "kernel param missing: $KERNELPARAM"
		exit -1
	fi
done

if [ "`netstat -nlp | grep :8080`" != "" ]; then
	echo "Someone already listening to port 8080"
	exit -1
fi

########## Prepare test dir #########################################

DIR="./result-${TESTNAME}"

if [ -d "$DIR" ]; then
	rm -rf "$DIR"
fi

mkdir "$DIR"

# contains all executed commands
COMMANDS_LOG="${DIR}/commands.log"

########## Fork off Spring, perf (if needed) and the periodic jcmd
##########    runner (if needed) ###################################

echo "PID of start script $0 : $$"

# Fork off spring
# We run spring on CPUs 0..11
TASKSET_SPRING="0xFFF"
GCLOG="-Xlog:gc -Xlog:metaspace*"
COMMAND="chrt -r 1 taskset ${TASKSET_SPRING} ${JDK_TO_TEST}/bin/java $WHATGC $WHAT_MAX_HEAPSIZE $JVM_ARGS $GCLOG -jar ./spring-petclinic-2.5.0-SNAPSHOT.jar"
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
	COMMAND="bash ./periodically-jcmd.sh ${FULL_GC_PERIOD} ${SPRING_PID}"
	start_process "$COMMAND" "jcmd"
	JCMD_PID=$PID
	echo "PID of jcmd script: $JCMD_PID"
fi

# wait until startup completed
sleep ${STARTUPTIME} 

# Sanity checks: All processes  should still be up

exit_if_process_not_found $SPRING_PID
if [ "$FULL_GC_PERIOD" != "" ]; then
	exit_if_process_not_found $JCMD_PID
fi
if [ "$PERF_COMMAND" != "" ]; then
	exit_if_process_not_found $PERF_PID
fi

########## Start jmeter and wait until its finished ###################################

JMETER_OPTIONS="-H localhost -P 8080 -t ${JMETER_SCRIPT} -n -e -l ${DIR}/jmeter.jtl -o ${DIR}/jmeter-report"

# We run jmeter on CPUs 12..15
TASKSET_JMETER="0xF000"
COMMAND="chrt -r 1 taskset ${TASKSET_JMETER} ${JDK_TO_TEST}/bin/java -jar ./apache-jmeter-5.6.3/bin/ApacheJMeter.jar ${JMETER_OPTIONS}"
start_process "$COMMAND" "jmeter"
JMETER_PID=$PID
echo "PID of jmeter process: $JMETER_PID"

# wait wait wait wait wait
while kill -0 "$JMETER_PID" 2> /dev/null; do sleep 1; done;

# big sigh - jmeter.log goes into the current dir, and its just simpler to move it to the
# result dir manually
if [ -f "./jmeter.log" ]; then
	mv "./jmeter.log" "$DIR"
fi

# stop spring 

# this should also kill perf and jcmd if they are running, but to be sure we kill them manually further down
# (and hope pids did not get reused in that time)
echo "Waiting for jmeter to finish..."
kill_process $SPRING_PID

if [ ! -z "${JCMD_PID:-}" ]; then
	kill_process $JCMD_PID
fi

if [ ! -z "${PERF_PID:-}" ]; then
	kill_process $PERF_PID
fi

sleep 2

chown -R thomas .

echo "Done."

