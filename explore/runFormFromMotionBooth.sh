#!/bin/bash
# Run explore/formFromMotionBooth.m as parallel MATLAB processes.
#
# Usage:
#   explore/runFormFromMotionBooth.sh <resultsFolder>
#
# 1. The "filters" job builds the booth templates and matched filters (one process).
# 2. The four booth coherences and the 1-s comparison run as five parallel
#    processes, about 4.5 GB of memory each.
# 3. The "analysis" job combines them and makes the tables and figures.
# 4. The results are copied into <resultsFolder>, which also gets one log per job.
#
# MATLAB: set MATLAB=/path/to/matlab to choose one. Otherwise matlab on the PATH
# is used, or else the newest /Applications/MATLAB_R*.app (a zsh alias for
# matlab is not visible to this script). Works in bash 3.2.

set -u
repo="$(cd "$(dirname "$0")/.." && pwd)"
results="${1:?Give a folder for the logs and results}"
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
    "$matlab" -batch "jobs = \"$1\"; run('explore/formFromMotionBooth.m')" > "$results/booth_$1.log" 2>&1
}

showFailure() {
    echo "The $1 job failed. The end of its log, $results/booth_$1.log:"
    tail -20 "$results/booth_$1.log"
}

echo "$(date): building the templates and matched filters"
if ! runJob filters; then
    showFailure filters
    exit 1
fi

echo "$(date): starting 5 parallel jobs"
parallelJobs=(coherence1 coherence2 coherence3 coherence4 model1s)
pids=()
for job in "${parallelJobs[@]}"; do
    runJob "$job" &
    pids+=($!)
done
failed=0
for k in "${!pids[@]}"; do
    if ! wait "${pids[$k]}"; then
        showFailure "${parallelJobs[$k]}"
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
cp explore/_figs/formFromMotionBooth* "$results/"
echo "$(date): done"
