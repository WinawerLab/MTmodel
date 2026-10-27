#!/bin/bash
# Run the jobs of a form-from-motion explore script as parallel MATLAB processes.
#
# Usage:
#   explore/runFormFromMotionJobs.sh <script> <numJobs> <resultsFolder>
# for example
#   explore/runFormFromMotionJobs.sh explore/formFromMotionBoothParasolGain.m 4 <resultsFolder>
#
# The script must accept a variable jobs = "job1" ... "jobN" or "analysis", as
# explore/formFromMotionBoothParasolGain.m does.
# 1. Runs job1 ... jobN, at most PARALLEL at a time [6]. A booth-size MATLAB
#    process takes about 4.5 GB of memory.
# 2. Runs the "analysis" job.
# 3. Copies explore/_figs/<script name>* into <resultsFolder>, which also gets one
#    log per job.
#
# SETUP: MATLAB statements run before the script in every job, to set the
# script's other variables, for example
#   SETUP="coherence = 0.5;" explore/runFormFromMotionJobs.sh explore/formFromMotionBoothLifetime.m 2 <resultsFolder>
#
# MATLAB: set MATLAB=/path/to/matlab to choose one. Otherwise matlab on the PATH
# is used, or else the newest /Applications/MATLAB_R*.app (a zsh alias for
# matlab is not visible to this script). Works in bash 3.2.

set -u
repo="$(cd "$(dirname "$0")/.." && pwd)"
script="${1:?Give the script, for example explore/formFromMotionBoothParasolGain.m}"
numJobs="${2:?Give the number of jobs}"
results="${3:?Give a folder for the logs and results}"
parallel="${PARALLEL:-6}"
setup="${SETUP:-}"
name="$(basename "$script" .m)"
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
if [ ! -f "$script" ]; then
    echo "$script was not found in $repo."
    exit 1
fi

runJob() {
    "$matlab" -batch "$setup jobs = \"$1\"; run('$script')" > "$results/${name}_$1.log" 2>&1
}

showFailure() {
    echo "The $1 job failed. The end of its log, $results/${name}_$1.log:"
    tail -20 "$results/${name}_$1.log"
}

echo "$(date): running $numJobs jobs of $script, at most $parallel at a time"
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
cp "explore/_figs/$name"* "$results/"
echo "$(date): done"
