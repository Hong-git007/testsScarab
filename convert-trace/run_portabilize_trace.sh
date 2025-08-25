#!/bin/bash
# Author: Hong (modified)
# Converts raw drmemtrace windows into Scarab-compatible trace folders

# --- Path Setup ---
SCRIPT=$(readlink -f "$0")
SCRIPTDIR=$(dirname "$SCRIPT")
TRACES_DIR=/home/HDD/hong/benchmarks/TRACE/SPEC17
FULL_BENCH_NAME="$1"
if [ -z "$FULL_BENCH_NAME" ]; then
    echo "Usage: $0 <FULL_BENCH_NAME>"
    exit 1
fi

echo "[INFO] Full bench name: $FULL_BENCH_NAME"

cd "$TRACES_DIR" || { echo "ERROR: Could not change to traces directory ($TRACES_DIR)."; exit 1; }

# --- Process each main trace directory ---
for dir in drmemtrace.${FULL_BENCH_NAME}*/; do
    echo "============================================================"
    echo "[INFO] Processing directory: $dir"

    (
        cd "$dir" || { echo "WARNING: Failed to cd into $dir. Skipping."; continue; }

        RAW_DIR=$(realpath ./raw)
        FINAL_TRACE_DIR=$(realpath ./trace)
        mkdir -p "$FINAL_TRACE_DIR"

        # --- Process each window ---
        for window_dir in "$RAW_DIR"/window.*; do
            window_name=$(basename "$window_dir")
            OUT_DIR="$FINAL_TRACE_DIR/$window_name"
            mkdir -p "$OUT_DIR"

            echo "[DEBUG] Converting $window_name into $OUT_DIR"

            # Run drraw2trace directly on the window folder
            if [ -x "${SCRIPTDIR}/../../tools/scarab/src/deps/dynamorio/build/clients/bin64/drraw2trace" ]; then
                "${SCRIPTDIR}/../../tools/scarab/src/deps/dynamorio/build/clients/bin64/drraw2trace" \
                    -indir "$window_dir" \
                    -out "$OUT_DIR"
            else
                echo "[ERROR] drraw2trace executable not found!"
                exit 1
            fi

            echo "[INFO] Finished converting $window_name"
        done

        echo "[INFO] Conversion for all windows in $dir completed."
    )
done

echo "============================================================"
echo "[SUCCESS] All trace conversions have completed successfully."