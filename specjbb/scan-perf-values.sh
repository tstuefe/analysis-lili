LC_NUMERIC=en_US.UTF-8

# $1 keyword, eg "LLC-loads" or "L1-dcache-load-misses"
function scan {

	echo "## $1"
	echo

	# Read raw values replace decimal points in big numbers
	RAW=`ack "$1" */composite.log | sed 's/,\([0-9]\)/\1/g'`
	echo '```'
	echo "$RAW"
	echo '```'
	echo

	# extract numbers for -COH
	echo "$RAW" | grep "COH-OFF" | sed 's/.*[: ]\([0-9][0-9]*\) .*/\1/g' > ./A
	# extract numbers for +COH
	echo "$RAW" | grep "COH-ON" | sed 's/.*[ :]\([0-9][0-9]*\) .*/\1/g' > ./B

	echo "-COH"
	echo '```'
	cat ./A
	echo '```'
	echo

	A_MEAN=`datamash mean 1 < ./A`
	A_SSTDEV=`datamash sstdev 1 < ./A`
	A_SSTDEV_PERC=`echo "($A_SSTDEV * 100.0) / $A_MEAN" | bc`
	echo "Mean:    $A_MEAN"
	echo "Sstdev:  $A_SSTDEV ($A_SSTDEV_PERC%)"

	echo "+COH"
	echo '```'
	cat ./B
	echo '```'
	echo

	B_MEAN=`datamash mean 1 < ./B`
	B2A=`echo "($B_MEAN * 100.0)/$A_MEAN" | bc`
	B_SSTDEV=`datamash sstdev 1 < ./B`
	B_SSTDEV_PERC=`echo "($B_SSTDEV * 100.0) / $B_MEAN" | bc`
	echo "Mean:    $B_MEAN"
	echo "         **${B2A}%**"
	echo "Sstdev:  $B_SSTDEV ($B_SSTDEV_PERC%)"
	

}


scan "L1-dcache-load-misses"
scan "L1-dcache-loads"
scan "LLC-load-misses"
scan "LLC-loads"
scan "dTLB-load-misses"
scan "dTLB-loads"
scan "instructions"
scan "branches"


