#!/bin/bash

###############################################################################
## Sample script for running SPECjbb2015 in Composite mode.
## 
## This sample script demonstrates launching the Controller, TxInjector and 
## Backend in a single JVM.
###############################################################################

# Launch command: java [options] -jar specjbb2015.jar [argument] [value] ...

# Benchmark options (-Dproperty=value to override the default and property file value)
# Please add -Dspecjbb.controller.host=$CTRL_IP (this host IP) and -Dspecjbb.time.server=true
# when launching Composite mode in virtual environment with Time Server located on the native host.
SPEC_OPTS=""

#WHATGC=-XX:+UseParallelGC
#WHATGC=-XX:+UseSerialGC
WHATGC_DEFAULT="-XX:+UseG1GC"
WHATGC=${WHATGC:-$WHATGC_DEFAULT}

WHAT_MAX_HEAPSIZE_DEFAULT="-Xmx6g"
WHAT_MAX_HEAPSIZE=${WHAT_MAX_HEAPSIZE:-$WHAT_MAX_HEAPSIZE}

# Java options for Composite JVM
JAVA_OPTS="$JVM_ARGS -Xlog:gc*  $WHATGC $WHAT_MAX_HEAPSIZE "

# Optional arguments for the Composite mode (-l <num>, -p <file>, -skipReport, etc.)
MODE_ARGS="-ikv"

# Number of successive runs
NUM_OF_RUNS=1

# isolate to Cpus 8 to 15
ISOLATE_CPUS_COMMAND_DEFAULT="chrt -r 1 taskset 0x3f "
ISOLATE_CPUS_COMMAND=${ISOLATE_CPUS_COMMAND:-$ISOLATE_CPUS_COMMAND_DEFAULT}

# Perf command
#PERF_COMMAND_DEFAULT="  perf stat  -B -e  L1-dcache-load-misses,L1-dcache-loads,LLC-load-misses,LLC-loads,dTLB-load-misses,dTLB-loads,instructions,branches "
PERF_COMMAND_DEFAULT=" "
PERF_COMMAND=${PERF_COMMAND:-$PERF_COMMAND_DEFAULT}

PRECOMMAND="$ISOLATE_CPUS_COMMAND $PERF_COMMAND "


###############################################################################
# This benchmark requires a JDK7 compliant Java VM.  If such a JVM is not on
# your path already you must set the JAVA environment variable to point to
# where the 'java' executable can be found.
###############################################################################

if [ "$JDK" == "" ]; then
	echo "Define JDK to point to JDK to test"
	exit -1
fi

JDK_BASENAME=$(basename $JDK)

JAVA=$JDK/bin/java


which $JAVA > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Could not find a 'java' executable. Please set the JAVA environment variable or update the PATH."
    exit 1
fi

for ((n=1; $n<=$NUM_OF_RUNS; n=$n+1)); do

  # Create result directory                
#  timestamp=$(date '+%y-%m-%d_%H%M%S')
#  result="./${JDK_BASENAME}-${TESTNAME}-${timestamp}"
  result="./results-${TESTNAME}"
  if [ -d ${result} ]; then
    echo "${result} already exists; adding timestamp to name"
    timestamp=$(date '+%y-%m-%d_%H%M%S')
    result="${result}-${timestamp}"
  fi

  mkdir $result

  # Copy current config to the result directory
  cp -r config $result

  cd $result

  echo "Run $n: $timestamp"
  echo "Launching SPECjbb2015 in Composite mode..."
  echo

  echo "Start Composite JVM...."
  COMMAND="$PRECOMMAND $JAVA $JAVA_OPTS $SPEC_OPTS -jar ../specjbb2015.jar -m COMPOSITE $MODE_ARGS"
  echo "Command line: $COMMAND"

  ${COMMAND} 2>composite.log > composite.out &

#    $PRECOMMAND $JAVA $JAVA_OPTS $SPEC_OPTS -jar ../specjbb2015.jar -m COMPOSITE $MODE_ARGS 2>composite.log > composite.out &

    COMPOSITE_PID=$!
    echo "Composite JVM PID = $COMPOSITE_PID"

  sleep 3

  echo
  echo "SPECjbb2015 is running..."
  echo "Please monitor $result/controller.out for progress"

  wait $COMPOSITE_PID
  echo
  echo "Composite JVM has stopped"

  echo "SPECjbb2015 has finished"
  echo

 cd ..

done

exit 0
