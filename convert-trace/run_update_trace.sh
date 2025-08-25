#!/bin/bash
# Author: Hong (modified)
# Wrapper script to portabilize Scarab traces using updateTraceModulePaths.py

# -------------------------------
# Config
# -------------------------------
SCRIPT=$(readlink -f "$0")
SCRIPTDIR=$(dirname "$SCRIPT")
TRACES_DIR=/home/HDD/hong/benchmarks/TRACE/SPEC17

FULL_BENCH_NAME="$1"
if [ -z "$FULL_BENCH_NAME" ]; then
    echo "Usage: $0 <FULL_BENCH_NAME>"
    exit 1
fi

echo "[INFO] Running updateTraceModulePaths.py for traces matching: drmemtrace.${FULL_BENCH_NAME}*"

cd "$TRACES_DIR" || { echo "ERROR: Could not change to traces directory ($TRACES_DIR)."; exit 1; }

# -------------------------------
# Process each trace directory
# -------------------------------
for dir in drmemtrace.${FULL_BENCH_NAME}*/; do
    echo "============================================================"
    echo "[INFO] Processing directory: $dir"

    cd "$dir" || { echo "WARNING: Failed to cd into $dir. Skipping."; continue; }

    if [ -f "raw/modules.log" ]; then
        echo "[INFO] Portabilizing trace in: $PWD"
        python3 "$SCRIPTDIR/updateTraceModulePaths.py" "$PWD"
    else
        echo "[WARNING] raw/modules.log not found in $PWD. Skipping."
    fi

    cd - >/dev/null
done

echo "============================================================"
echo "[SUCCESS] All trace directories have been processed."