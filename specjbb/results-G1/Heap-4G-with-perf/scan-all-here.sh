#!/bin/bash

# one stop script to scan all output of a number of specjbb runs

set -euo pipefail

SCRIPTDIR="/shared/projects/openjdk/analysis/liliput-benefits/specjbb"

# scan perf output
echo "**** COH-OFF *****"
echo
bash $SCRIPTDIR/scan-perf-values.sh COH-OFF results-COH-OFF-G1-with-perf-*/composite.log

echo
echo "**** COH-ON *****"
echo
bash ${SCRIPTDIR}/scan-perf-values.sh COH-ON results-COH-ON-G1-with-perf-*/composite.log

# scan jvm metrics from logs
echo
echo "**** COH-OFF *****"
echo
bash $SCRIPTDIR/scan-jvm-metrics.sh COH-OFF results-COH-OFF-G1-with-perf-*/composite.out
echo
echo "**** COH-ON *****"
echo
bash $SCRIPTDIR/scan-jvm-metrics.sh COH-ON results-COH-ON-G1-with-perf-*/composite.out

# scan jbb rsults
echo
echo "**** COH-OFF *****"
echo
bash $SCRIPTDIR/scan-specJBB-results.sh COH-OFF results-COH-OFF-G1-with-perf-*
echo
echo "**** COH-ON *****"
echo
bash $SCRIPTDIR/scan-specJBB-results.sh COH-ON results-COH-ON-G1-with-perf-*

