# -COH to +COH

##G1

### SpecJBB2015, 4GB heap, 10 Runs:

- GC Pause Time (WCT): 				-24%
  (CPU times accordingly)
- SpecJBB result maxJops/critJops:  +6.0/6.4%

### SpecJBB2015, 8GB heap, 10 Runs, periodically doing Full GCs to get liveset size:

- Liveset Size post-full-GC:        -17.34 %

### SpecJBB2015, 4GB heap, 18 Runs, with perf stat

- L1 Misses                         -14.32%
- L1 Loads                          -15.29%
- LLC Misses                        -22.34%
- LLC Loads                         -15.20%
- TLB Misses                        -14.16%
- TLB Loads                         -15.30%
- Instructions                      -13.68%
- Branches                          -16.31%
