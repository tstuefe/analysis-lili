
# If current user is not root, warn and exit
function exit_if_not_root () {
	if [ `id -u` -ne 0 ]
  		then echo Please run this script as root or using sudo!
 		exit
	fi
}


# Given a dir name, if it exists, rename it to 
# <dir>-0. If <dir-0> exist, rename it to <dir-1>
# etc.
#
# $1 dir name
function rename_old_dir_if_needed () {
	if [ -d "$1" ]; then
		for A in `seq 0 100`; do
			local target="${1}-${A}"
			if [ ! -d "$target" ]; then
				mv "$1" "$target"
				break
			fi
		done
	fi
}

# Given a dir name, create it. If it exist, delete it first, then re-create.
function create_dir_delete_old () {
	if [ -d "$1" ]; then
		rm -rf "$1"
	fi
	mkdir -p "$1"
}


# If process with given pid is not found, exit script
# $1 pid
# $2 name
function exit_if_process_not_found () {
	if [ ! -d "/proc/$1" ]; then
		echo "Process not found ($1 $2)"
		exit -1
	fi
}

# Kill process $1
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
	$1 > "${2}.out" 2> "${2}.err" &
	PID=$!
} 

# $1 pid
function wait_for_process_to_finish () {
	while kill -0 "$1" 2> /dev/null; do sleep 1; done;
}


# Warn and exit if machine has not been stabilized
function exit_if_machine_is_not_stabilized_for_benchmarks () {
	# we expect to have CPUs isolated (the exact number depends on configuration,
        # we just trust here that this matches the taskset later)
	for A in "isolcpus" "nohz_full"; do
		if [ "`cat /proc/cmdline | grep $A`" == "" ]; then
			echo "kernel param missing: $A"
			exit -1
		fi
	done

	if [[ `sysctl kernel.randomize_va_space` != "kernel.randomize_va_space = 0" ]]; then
        	echo "stabilize machine for benchmark! (run prepare script?)";
		exit -1
	fi
}

# Warn and exit if someone is listening to port $1
function exit_if_port_is_occupied () {
	if [ "`netstat -nlp | grep :${1}`" != "" ]; then
		echo "Someone already listening to port $1"
		exit -1
	fi
}







