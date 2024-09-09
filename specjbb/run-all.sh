JDK_TO_TEST="${PWD}/../jdk-lilliput"

if [ `id -u` -ne 0 ]
  then echo Please run this script as root or using sudo!
  exit
fi

export JAVA_ARGS='--add-modules java.xml.bind'

#export PERF_COMMAND="perf stat  -B -e  L1-dcache-load-misses,L1-dcache-loads,LLC-load-misses,LLC-loads,dTLB-load-misses,dTLB-loads "

# see /proc/cmdline: we run with isolcpu 0-6
ISOLATE_CPUS_COMMAND="chrt -r 1 taskset 0x3f "

NUM_RUNS=1

for (( run=0; run < $NUM_RUNS; run++ )); do

export JDK=$JDK_TO_TEST
export JVM_ARGS="-XX:+UnlockExperimentalVMOptions -XX:+UseCompactObjectHeaders -Xshare:off"
export TESTNAME="COH-ON-${run}"
bash ./run_composite.sh

export JDK=$JDK_TO_TEST
export JVM_ARGS="-XX:+UnlockExperimentalVMOptions -XX:-UseCompactObjectHeaders -Xshare:off"
export TESTNAME="COH-OFF-${run}"
bash ./run_composite.sh

done

