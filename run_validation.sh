#!/bin/bash
# Regenerate the SH Figs 9-14 baseline figures.
#
# Note: the results these produce were measured through the pre-mtMix MT and are
# superseded. See docs/MODEL_AND_LESIONS.md section 5. Set MATLAB_BIN if the
# matlab binary is not on your PATH.

set -e
repoRoot="$(cd "$(dirname "$0")" && pwd)"
"${MATLAB_BIN:-matlab}" -batch "run('$repoRoot/explore/validateSHFigs9to14.m')"
