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
# Set MATLAB=/path/to/matlab if matlab is not on the PATH. Works in bash 3.2.

set -u
repo="$(cd "$(dirname "$0")/.." && pwd)"
results="${1:?Give a folder for the logs and results}"
matlab="${MATLAB:-matlab}"
mkdir -p "$results"
cd "$repo" || exit 1

runJob() {
    "$matlab" -batch "jobs = \"$1\"; run('explore/formFromMotionBooth.m')" > "$results/booth_$1.log" 2>&1
}

echo "$(date): building the templates and matched filters"
if ! runJob filters; then
    echo "The filters job failed; see $results/booth_filters.log"
    exit 1
fi

echo "$(date): starting 5 parallel jobs"
pids=()
for job in coherence1 coherence2 coherence3 coherence4 model1s; do
    runJob "$job" &
    pids+=($!)
done
failed=0
for pid in "${pids[@]}"; do
    wait "$pid" || failed=1
done
if [ "$failed" -ne 0 ]; then
    echo "At least one job failed; see the logs in $results"
    exit 1
fi

echo "$(date): combining the jobs"
if ! runJob analysis; then
    echo "The analysis job failed; see $results/booth_analysis.log"
    exit 1
fi
cp explore/_figs/formFromMotionBooth* "$results/"
echo "$(date): done"
