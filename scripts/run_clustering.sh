#!/bin/bash

source /home/hong/simulator/Benchmarking/tools/scarab-infra/scripts/utilities.sh

FPFILE=$1
OUTDIR=$2
USERK=${3:-0}  # maxk를 사용자 지정 가능, 지정 안 하면 0

echo "[DEBUG] FPFILE: $FPFILE"
echo "[DEBUG] OUTDIR: $OUTDIR"
echo "[DEBUG] USERK: $USERK"

# FPFILE 존재 여부 체크
if [ ! -f "$FPFILE" ]; then
    echo "[ERROR] Fingerprint file does not exist: $FPFILE"
    exit 1
fi

# OUTDIR 존재 여부 확인 및 생성
if [ ! -d "$OUTDIR" ]; then
    echo "[DEBUG] OUTDIR does not exist. Creating..."
    mkdir -p "$OUTDIR"
fi
cd "$OUTDIR" || { echo "[ERROR] Failed to cd into $OUTDIR"; exit 1; }

# simpoints 디렉토리 생성
mkdir -p simpoints
echo "[DEBUG] simpoints directory created at $OUTDIR/simpoints"

# SimPoint 실행 파일 경로 지정
SIMPOINT_EXEC="$scarab_tool/SimPoint.3.2/bin/simpoint"
if [ ! -x "$SIMPOINT_EXEC" ]; then
    echo "[ERROR] SimPoint executable not found or not executable: $SIMPOINT_EXEC"
    exit 1
fi

# maxK 계산
if [ "$USERK" == "0" ]; then
    lines=$(wc -l < "$FPFILE")
    maxK=$(echo "(sqrt($lines)+0.5)/1" | bc)
else
    maxK=$USERK
fi

echo "[DEBUG] fingerprint size: $lines, maxK: $maxK"

# SimPoint 명령어 구성
spCmd="$SIMPOINT_EXEC -maxK $maxK -fixedLength off -numInitSeeds 10 \
-loadFVFile $FPFILE \
-saveSimpoints $OUTDIR/simpoints/opt.p \
-saveSimpointWeights $OUTDIR/simpoints/opt.w \
-saveVectorWeights $OUTDIR/simpoints/vector.w \
-saveLabels $OUTDIR/simpoints/opt.l \
-coveragePct .99"

echo "[DEBUG] cluster fingerprint command: ${spCmd}"

# SimPoint 실행
start=$(date +%s)
$spCmd &> "$OUTDIR/simpoints/simp.opt.log"
ret=$?
end=$(date +%s)

if [ $ret -ne 0 ]; then
    echo "[ERROR] SimPoint failed. Check log: $OUTDIR/simpoints/simp.opt.log"
    exit 1
fi

report_time "simpointing" "$start" "$end"
echo "[DEBUG] SimPoint clustering finished."

exit 0
