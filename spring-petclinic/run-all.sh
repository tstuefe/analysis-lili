JDK_TO_TEST="${PWD}/../jdk-liliput"

if [ `id -u` -ne 0 ]
  then echo Please run this script as root or using sudo!
  exit
fi

# prepare stability
if [[ `sysctl kernel.randomize_va_space` != "kernel.randomize_va_space = 0" ]]; then
	echo "stabilize machine for benchmark!";
fi

echo "PID of $0 : $$"

#export PERF_COMMAND="perf stat --no-big-num -e  L1-dcache-load-misses,L1-dcache-loads,LLC-load-misses,LLC-loads,dTLB-load-misses,dTLB-loads,instructions,branches"
#export PERF_COMMAND=" "

NUM_RUNS=4

for (( run=0; run < $NUM_RUNS; run++ )); do

# Parallel
export TESTNAME_BASE="Parallel-8G"
export WHATGC="-XX:+UseParallelGC"
export WHAT_MAX_HEAPSIZE="-Xmx8g"

export JDK=$JDK_TO_TEST
export JVM_ARGS="-XX:+UnlockExperimentalVMOptions -XX:+UseCompactObjectHeaders -Xshare:off"
export TESTNAME="COH-ON-${TESTNAME_BASE}-${run}"
bash ./run-single-test.sh

export JDK=$JDK_TO_TEST
export JVM_ARGS="-XX:+UnlockExperimentalVMOptions -XX:-UseCompactObjectHeaders -Xshare:off"
export TESTNAME="COH-OFF-${TESTNAME_BASE}-${run}"
bash ./run-single-test.sh

done


