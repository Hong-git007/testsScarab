#!/bin/bash

#----------------------------------------
# 경로 설정
#----------------------------------------
SIM_OUT="/home/HDD/hong/simulation_results/scarab"
TRACE_DIR="/home/HDD/hong/benchmarks/TRACE/SPEC17"
SCARAB_BIN="/home/hong/simulator/Benchmarking/tools/scarab/src/scarab"
DRRAW2TRACE_BIN="/home/hong/simulator/Benchmarking/tools/DynamoRIO-Linux-10.0.0/tools/bin64/drraw2trace"
SIM_INST=400000000
WARMUP_INST=200000000  # 웜업 instruction 수

SCARAB_ARGS="--full_warmup=$WARMUP_INST"

PARAM_DIR="/home/hong/simulator/Benchmarking/testsScarab/param"
PARAM="$PARAM_DIR/PARAMS.golden_cove"

#----------------------------------------
# 처리할 벤치마크 및 모드
#----------------------------------------
BENCHMARKS=("gcc_17_r_ref1" "gcc_17_r_ref3" "gcc_17_r_ref4")
MODES=("baseline" "perfect")

#----------------------------------------
# 실패한 윈도우 감지
#----------------------------------------
detect_failed_windows() {
    local MODE_DIR=$1
    local BMK=$2
    FAILED_WINDOWS=()
    echo "[DEBUG] Scanning for failed windows in $MODE_DIR/$BMK"
    for WIN_DIR in "$MODE_DIR/$BMK"/window.*; do
        if [[ -d "$WIN_DIR" ]]; then
            echo "[DEBUG] Checking $WIN_DIR"
            STDOUT_FILE="$WIN_DIR/stdout.out"
            STDERR_FILE="$WIN_DIR/stderr.out"
            BP_FILE="$WIN_DIR/bp.stat.0.csv"

            echo "       stdout exists: $([[ -f "$STDOUT_FILE" ]] && echo yes || echo no)"
            echo "       stderr exists: $([[ -f "$STDERR_FILE" ]] && echo yes || echo no)"
            echo "       bp.stat.0.csv exists: $([[ -f "$BP_FILE" ]] && echo yes || echo no)"

            if [[ -f "$STDOUT_FILE" ]] && [[ -f "$STDERR_FILE" ]] && [[ ! -f "$BP_FILE" ]]; then
                echo "[DEBUG] Failed window detected: $WIN_DIR"
                FAILED_WINDOWS+=("$WIN_DIR")
            else
                echo "[DEBUG] Window OK, skipping: $WIN_DIR"
            fi
        fi
    done
}

#----------------------------------------
# non-compress trace 생성
#----------------------------------------
generate_noncompress_trace() {
    local WIN_DIR="$1"
    local BMK="$2"

    WIN_NAME=$(basename "$WIN_DIR")
    WIN_NUM=${WIN_NAME%%_*}
    WIN_NUM=${WIN_NUM#window.}
    WIN_NUM=$((10#$WIN_NUM))

    TRACE_BASE="$TRACE_DIR/$BMK/traces_simp/$WIN_NUM"
    TRACE_OUT_DIR="$TRACE_DIR/$BMK/traces_simp/trace/${WIN_NAME}_nocompress"

    echo "[DEBUG] Preparing non-compress trace for $WIN_NAME"
    echo "       TRACE_BASE: $TRACE_BASE"
    echo "       TRACE_OUT_DIR: $TRACE_OUT_DIR"

    if [[ -d "$TRACE_OUT_DIR" ]]; then
        echo "[DEBUG] Non-compress trace already exists: $TRACE_OUT_DIR"
        return 0
    fi

    RAW_DIR=$(find "$TRACE_BASE" -maxdepth 1 -type d -name "drmemtrace.*.dir" | head -n1)/raw
    if [ ! -d "$RAW_DIR" ]; then
        echo "[ERROR] Raw trace directory not found for $WIN_NAME: $RAW_DIR"
        return 1
    fi

    mkdir -p "$TRACE_OUT_DIR"

    echo "[DEBUG] Command: $DRRAW2TRACE_BIN -indir $RAW_DIR -out $TRACE_OUT_DIR -compress none"
    "$DRRAW2TRACE_BIN" -indir "$RAW_DIR" -out "$TRACE_OUT_DIR" -compress none
    return $?
}

#----------------------------------------
# Scarab 실행
#----------------------------------------
run_scarab() {
    local WIN_DIR=$1
    local MODE=$2
    local BMK=$3

    WIN_NAME=$(basename "$WIN_DIR")
    TRACE_DIR_FINAL="$TRACE_DIR/$BMK/traces_simp/trace/${WIN_NAME}_nocompress"
    TRACE_FILE=$(ls "$TRACE_DIR_FINAL"/drmemtrace.*.trace 2>/dev/null | head -n1)

    if [ ! -f "$TRACE_FILE" ]; then
        echo "[ERROR] Trace file not found: $TRACE_FILE"
        return 1
    fi

    OUT_DIR="$SIM_OUT/$MODE/$BMK/${WIN_NAME}_nocompress"
    mkdir -p "$OUT_DIR"

    # PARAMS.in 복사
    if [[ -f "$PARAM" ]]; then
        cp "$PARAM" "$OUT_DIR/PARAMS.in"
        echo "[DEBUG] Copied PARAM file:"
        echo "       Source: $PARAM"
        echo "       Destination: $OUT_DIR/PARAMS.in"
    else
        echo "[DEBUG] PARAM file not found, skipping copy: $PARAM"
    fi

    # Scarab 실행
    pushd "$OUT_DIR" > /dev/null  # OUT_DIR로 이동
    CMD=(
        "$SCARAB_BIN"
        --frontend memtrace
        --cbp_trace_r0="$TRACE_FILE"
        --inst_limit="$SIM_INST"
        --output_dir="$OUT_DIR"
        --stdout=stdout
        --stderr=stderr
        --trace_bbv_output=bbv_output.txt
        --trace_footprint_output=footprint.txt
        $SCARAB_ARGS
    )
    [[ "$MODE" == "perfect" ]] && CMD+=("--perfect_bp" "1" "--perfect_target" "1")

    echo "[DEBUG] Running Scarab: ${CMD[*]}"
    "${CMD[@]}"
    local RET=$?
    popd > /dev/null  # 원래 디렉토리로 복귀
    return $RET
}


#----------------------------------------
# 메인 루프
#----------------------------------------
MAX_JOBS=$(nproc)
BMK_JOBS=()

for BMK in "${BENCHMARKS[@]}"; do
    (
        echo "=== Processing benchmark: $BMK ==="
        for MODE in "${MODES[@]}"; do
            detect_failed_windows "$SIM_OUT/$MODE" "$BMK"

            if [[ "${#FAILED_WINDOWS[@]}" -eq 0 ]]; then
                echo "[DEBUG] No failed windows found for $BMK/$MODE, skipping."
                continue
            fi

            JOBS=()
            for WIN_DIR in "${FAILED_WINDOWS[@]}"; do
                (
                    echo "[DEBUG] Processing window: $WIN_DIR"
                    generate_noncompress_trace "$WIN_DIR" "$BMK" && run_scarab "$WIN_DIR" "$MODE" "$BMK"
                ) &

                JOBS+=($!)

                if [[ "${#JOBS[@]}" -ge "$MAX_JOBS" ]]; then
                    echo "[DEBUG] Waiting for batch of ${#JOBS[@]} jobs for $BMK/$MODE..."
                    wait "${JOBS[@]}"
                    JOBS=()
                fi
            done

            [[ "${#JOBS[@]}" -gt 0 ]] && wait "${JOBS[@]}"
        done
    ) &  # 벤치마크 단위로 백그라운드 실행
    BMK_JOBS+=($!)

    # BMK_JOBS 갯수가 CPU 코어 수보다 많으면 wait
    if [[ "${#BMK_JOBS[@]}" -ge "$MAX_JOBS" ]]; then
        echo "[DEBUG] Waiting for batch of ${#BMK_JOBS[@]} benchmarks..."
        wait "${BMK_JOBS[@]}"
        BMK_JOBS=()
    fi
done

# 남은 벤치마크 jobs wait
if [[ "${#BMK_JOBS[@]}" -gt 0 ]]; then
    echo "[DEBUG] Waiting for final batch of ${#BMK_JOBS[@]} benchmarks..."
    wait "${BMK_JOBS[@]}"
fi

echo "All done."
