#!/bin/bash
# Run explore/formFromMotionBoothNoise.m as parallel MATLAB processes.
#
# Usage:
#   explore/runFormFromMotionBoothNoise.sh <resultsFolder>
#
# 1. Runs job1 ... job12 (one RGC noise level and coherence each), at most
#    PARALLEL at a time [6]. Each MATLAB process takes about 4.5 GB of memory.
# 2. The "analysis" job combines them with the no-noise run and makes the
#    tables and figures.
# 3. The results are copied into <resultsFolder>, which also gets one log per job.
#
# Needs the no-noise booth run's results in explore/_figs/
# (explore/runFormFromMotionBooth.sh).
#
# MATLAB: set MATLAB=/path/to/matlab to choose one. Otherwise matlab on the PATH
# is used, or else the newest /Applications/MATLAB_R*.app (a zsh alias for
# matlab is not visible to this script). Works in bash 3.2.

set -u
repo="$(cd "$(dirname "$0")/.." && pwd)"
results="${1:?Give a folder for the logs and results}"
parallel="${PARALLEL:-6}"
numJobs=12    # must match the number of jobs in explore/formFromMotionBoothNoise.m
matlab="${MATLAB:-matlab}"
if ! command -v "$matlab" > /dev/null 2>&1; then
    newest="$(ls -d /Applications/MATLAB_R*.app 2> /dev/null | tail -1)"
    if [ -z "$newest" ]; then
        echo "MATLAB was not found. Set MATLAB=/path/to/matlab and run again."
        exit 1
    fi
    matlab="$newest/bin/matlab"
fi
echo "Using $matlab"
mkdir -p "$results"
cd "$repo" || exit 1

runJob() {
    "$matlab" -batch "jobs = \"$1\"; run('explore/formFromMotionBoothNoise.m')" \
        > "$results/boothNoise_$1.log" 2>&1
}

showFailure() {
    echo "The $1 job failed. The end of its log, $results/boothNoise_$1.log:"
    tail -20 "$results/boothNoise_$1.log"
}

echo "$(date): running $numJobs jobs, at most $parallel at a time"
pids=()
names=()
for k in $(seq 1 "$numJobs"); do
    while [ "$(jobs -rp | wc -l | tr -d ' ')" -ge "$parallel" ]; do
        sleep 30
    done
    echo "$(date): starting job$k"
    runJob "job$k" &
    pids+=($!)
    names+=("job$k")
done
failed=0
for k in "${!pids[@]}"; do
    if ! wait "${pids[$k]}"; then
        showFailure "${names[$k]}"
        failed=1
    fi
done
if [ "$failed" -ne 0 ]; then
    exit 1
fi

echo "$(date): combining the jobs"
if ! runJob analysis; then
    showFailure analysis
    exit 1
fi
cp explore/_figs/formFromMotionBoothNoise* "$results/"
echo "$(date): done"
