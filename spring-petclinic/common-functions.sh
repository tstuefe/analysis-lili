
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
echo RENAMEIN
		for A in `seq 0 100`; do
			local target="${1}-${A}"
			if [ ! -d "$target" ]; then
				mv "$1" "$target"
				break
			fi
		done
	fi
}
