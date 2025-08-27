# Author: Hong (modified)
# Polytech Montpellier - 2025
SHELL := /bin/bash

# ===================== 컴파일러 =====================
CC = gcc
CPP = g++
CFLAGS = -O0

# ===================== 절대경로 =====================
SCARAB_DIR = /home/hong/simulator/Benchmarking/tools/scarab
PARAM_DIR = /home/hong/simulator/Benchmarking/testsScarab/param
TRACE_DIR = /home/HDD/hong/benchmarks/TRACE/SPEC17
CONVERT_TRACE_DIR = /home/hong/simulator/Benchmarking/testsScarab/convert-trace
CODES_DIR = /home/hong/simulator/Benchmarking/testsScarab/codes
SIMPOINTS_DIR = /home/hong/simulator/Benchmarking/testsScarab/simpoint
SIM_OUT = /home/HDD/hong/simulation_results/scarab

# ===================== BENCH 설정 =====================
BENCH_LIST ?= \
	perlbench_17_r_ref0 perlbench_17_r_ref1 perlbench_17_r_ref2 \
	gcc_17_r_ref0 gcc_17_r_ref1 gcc_17_r_ref2 gcc_17_r_ref3 gcc_17_r_ref4 \
	omnetpp_17_r_ref0 \
	xalancbmk_17_r_ref0 \
	x264_17_r_ref0 x264_17_r_ref1 x264_17_r_ref2 \
	deepsjeng_17_r_ref0 \
	leela_17_r_ref0 \
	mcf_17_r_ref0 \
	exchange2_17_r_ref0 \
	xz_17_r_ref0 xz_17_r_ref1 xz_17_r_ref2 \
	bwaves_17_r_ref0 bwaves_17_r_ref1 bwaves_17_r_ref2 bwaves_17_r_ref3 \
	cactuBSSN_17_r_ref0 \
	namd_17_r_ref0 \
	parest_17_r_ref0 \
	povray_17_r_ref0 \
	lbm_17_r_ref0 \
	wrf_17_r_ref0 \
	blender_17_r_ref0 \
	cam4_17_r_ref0 \
	imagick_17_r_ref0 \
	nab_17_r_ref0 \
	fotonik3d_17_r_ref0 \
	roms_17_r_ref0

BENCH_NAME ?= $(firstword $(BENCH_LIST))
SHORT_BENCH_NAME := $(shell echo $(BENCH_NAME) | cut -d'_' -f1)

# bench_paths.mk include
include $(SIMPOINTS_DIR)/bench_paths.mk

# BENCH_NAME 기반 변수 선택
PROGRAM = $(PROGRAM_$(BENCH_NAME))
PROGRAM_ARGS = $(PROGRAM_ARGS_$(BENCH_NAME))
SIMPOINTS_FILE_WEIGHT = $(SIMPOINTS_FILE_WEIGHT_$(BENCH_NAME))
BINARY_DIR = $(BINARY_DIR_$(BENCH_NAME))
PARAM ?= $(PARAM_DIR)/PARAMS.golden_cove

# ===================== 시뮬레이션 설정 =====================
SIMULATION_INSTRUCTIONS = 400000000
WARMUP_INSTRUCTIONS = 200000000
SCARAB_ARGS ?= --full_warmup=$(WARMUP_INSTRUCTIONS)

# Python workflow 경로
PYTHON_SCRIPT = /home/hong/simulator/Benchmarking/testsScarab/scripts/run_simpoint_trace.py
SCRIPT_HOME_DIR = /home/hong/simulator/Benchmarking/testsScarab/scripts

# ===================== 실행 예제 =====================
run:
	@echo "==================== RUN CONFIGURATION ===================="
	@echo "BENCH_NAME: $(BENCH_NAME)"
	@echo "SHORT_BENCH_NAME: $(SHORT_BENCH_NAME)"
	@echo "PROGRAM: $(PROGRAM)"
	@echo "PROGRAM_ARGS: $(PROGRAM_ARGS)"
	@echo "BINARY_DIR: $(BINARY_DIR)"
	@echo "PARAM: $(PARAM)"
	@echo "SIMPOINTS_FILE_WEIGHT: $(SIMPOINTS_FILE_WEIGHT)"
	@echo "SIMPOINTS_DIR: $(SIMPOINTS_DIR)"
	@echo "TRACE_DIR: $(TRACE_DIR)"
	@echo "CONVERT_TRACE_DIR: $(CONVERT_TRACE_DIR)"
	@echo "SCARAB_DIR: $(SCARAB_DIR)"
	@echo "SCARAB_ARGS: $(SCARAB_ARGS)"
	@echo "SIM_OUT: $(SIM_OUT)"
	@echo "SIMULATION_INSTRUCTIONS: $(SIMULATION_INSTRUCTIONS)"
	@echo "WARMUP_INSTRUCTIONS: $(WARMUP_INSTRUCTIONS)"
	@echo "PYTHON_SCRIPT: $(PYTHON_SCRIPT)"
	@echo "SCRIPT_HOME_DIR: $(SCRIPT_HOME_DIR)"
	@echo "EXIT_AFTER_TRACING: $(EXIT_AFTER_TRACING)"
	@echo "============================================================"


# ===================== 기본 타겟 =====================
.PHONY: all compile clean clean_outputs run run-all trace-all launch-all trace-all-parallel launch-all-parallel process-all-csv process-all-bench-csv

all: trace-all-parallel launch-all-parallel process-all-bench-csv

compile:
	@mkdir -p $(BINARY_DIR)
	@if [ -z "$(strip $(PROGRAM))" ]; then \
		for file in $(CODES_DIR)/*.c $(CODES_DIR)/*.cpp; do \
			[ -e "$$file" ] || continue; \
			base_file=$$(basename "$$file"); \
			case "$$file" in \
				*.cpp) $(CPP) $(CFLAGS) -o $(BINARY_DIR)/$${base_file%.cpp} "$$file";; \
				*.c) $(CC) $(CFLAGS) -o $(BINARY_DIR)/$${base_file%.c} "$$file";; \
			esac; \
		done \
	else \
		if [ -f $(CODES_DIR)/$(PROGRAM).cpp ]; then \
			$(CPP) $(CFLAGS) -o $(BINARY_DIR)/$(PROGRAM) $(CODES_DIR)/$(PROGRAM).cpp; \
		elif [ -f $(CODES_DIR)/$(PROGRAM).c ]; then \
			$(CC) $(CFLAGS) -o $(BINARY_DIR)/$(PROGRAM) $(CODES_DIR)/$(PROGRAM).c; \
		else \
			echo "Source file for $(PROGRAM) not found in $(CODES_DIR)"; exit 1; \
		fi \
	fi

# ===================== SimPoint + Trace via Python =====================
trace-simpoint-via-python:
	@echo "--- Starting SimPoint workflow via Python script for $(BENCH_NAME) ---"
	@mkdir -p $(TRACE_DIR)
	@python3 $(PYTHON_SCRIPT) \
		--workload $(BENCH_NAME) \
		--suite spec \
		--simpoint_home $(TRACE_DIR) \
		--bincmd "$(BINARY_DIR)/$(PROGRAM) $(PROGRAM_ARGS)" \
		--simpoint_mode 1 \
		--clustering_userk 5 \
		--scarab_root $(SCARAB_DIR) \
		--script_home $(SCRIPT_HOME_DIR)
	@echo "--- SimPoint workflow finished for $(BENCH_NAME) ---"

# ===================== Scarab 실행 =====================
launch-trace:
	@mkdir -p $(SIM_OUT)/baseline
	@cp $(PARAM) PARAMS.in
	TRACE_BASE=$(TRACE_DIR)/$(BENCH_NAME)/traces_simp/trace && \
	if [ ! -d "$$TRACE_BASE" ]; then \
		echo "[ERROR] Trace directory for $(BENCH_NAME) not found at $$TRACE_BASE."; exit 1; \
	fi && \
	WINDOW_DIRS=$$(find $$TRACE_BASE -mindepth 1 -maxdepth 1 -type d | sort) && \
	for w in $$WINDOW_DIRS; do \
		WIN_NAME=$$(basename $$w); \
		WIN_IDX=$$(echo $$WIN_NAME | awk -F'_' '{print $$2}' | sed 's/^0*\([0-9]\)/\1/'); \
		LINE=$$(awk '$$2=='"$$WIN_IDX"' {print}' $(TRACE_DIR)/$(BENCH_NAME)/simpoints/opt.w.lpt0.99); \
		WEIGHT=$$(echo $$LINE | awk '{print $$1}'); \
		WIN_FINAL="$${WIN_NAME}_$${WEIGHT}"; \
		TRACE_FILE=$$(find $$w -maxdepth 1 -name 'drmemtrace.*.trace.zip' | sort | head -n 1); \
		mkdir -p $(SIM_OUT)/baseline/$(BENCH_NAME)/$$WIN_FINAL; \
		echo "Launching Scarab on window: $$WIN_FINAL with trace $$TRACE_FILE"; \
		$(SCARAB_DIR)/src/scarab --frontend memtrace \
			--cbp_trace_r0=$$TRACE_FILE \
			--inst_limit=$(SIMULATION_INSTRUCTIONS) \
			--output_dir=$(SIM_OUT)/baseline/$(BENCH_NAME)/$$WIN_FINAL \
			--stdout=stdout \
			--stderr=stderr \
			--trace_bbv_output=bbv_output.txt \
			--trace_footprint_output=footprint.txt \
			$(SCARAB_ARGS); \
	done

launch-trace-perfect:
	@mkdir -p $(SIM_OUT)/perfect
	@cp $(PARAM) PARAMS.in
	TRACE_BASE=$(TRACE_DIR)/$(BENCH_NAME)/traces_simp/trace && \
	if [ ! -d "$$TRACE_BASE" ]; then \
		echo "[ERROR] Trace directory for $(BENCH_NAME) not found at $$TRACE_BASE."; exit 1; \
	fi && \
	WINDOW_DIRS=$$(find $$TRACE_BASE -mindepth 1 -maxdepth 1 -type d | sort) && \
	for w in $$WINDOW_DIRS; do \
		WIN_NAME=$$(basename $$w); \
		WIN_IDX=$$(echo $$WIN_NAME | awk -F'_' '{print $$2}' | sed 's/^0*\([0-9]\)/\1/'); \
		LINE=$$(awk '$$2=='"$$WIN_IDX"' {print}' $(TRACE_DIR)/$(BENCH_NAME)/simpoints/opt.w.lpt0.99); \
		WEIGHT=$$(echo $$LINE | awk '{print $$1}'); \
		WIN_FINAL="$${WIN_NAME}_$${WEIGHT}"; \
		TRACE_FILE=$$(find $$w -maxdepth 1 -name 'drmemtrace.*.trace.zip' | sort | head -n 1); \
		mkdir -p $(SIM_OUT)/perfect/$(BENCH_NAME)/$$WIN_FINAL; \
		echo "Launching Scarab on window: $$WIN_FINAL with trace $$TRACE_FILE"; \
		$(SCARAB_DIR)/src/scarab --frontend memtrace \
			--cbp_trace_r0=$$TRACE_FILE \
			--inst_limit=$(SIMULATION_INSTRUCTIONS) \
			--output_dir=$(SIM_OUT)/perfect/$(BENCH_NAME)/$$WIN_FINAL \
			--stdout=stdout \
			--stderr=stderr \
			--trace_bbv_output=bbv_output.txt \
			--trace_footprint_output=footprint.txt \
			$(SCARAB_ARGS) --perfect_bp 1 --perfect_target 1; \
	done

# ===================== 모든 CSV 파일 생성 및 최종 합계 포함 =====================
process-all-csv:
	@echo "--- Processing simulation outputs and creating CSVs for both baseline and perfect ---"
	@for target_folder in baseline perfect; do \
		echo "Processing $$target_folder folder..."; \
		\
		mkdir -p $(SIM_OUT)/$$target_folder/$(BENCH_NAME); \
		CSV_FILE=$(SIM_OUT)/$$target_folder/$(BENCH_NAME)/results.csv; \
		\
		if [ -f "$$CSV_FILE" ]; then \
			echo "Removing existing CSV file: $$CSV_FILE"; \
			rm "$$CSV_FILE"; \
		fi; \
		\
		printf "%-20s %15s %15s %15s\n" "SimPoint" "Weight" "IPC" "MPKI" > "$$CSV_FILE"; \
		\
		TOTAL_WEIGHT=0; \
		TOTAL_WEIGHTED_IPC=0; \
		TOTAL_WEIGHTED_MPKI=0; \
		\
		TRACE_BASE=$(TRACE_DIR)/$(BENCH_NAME)/traces_simp/trace; \
		if [ ! -d "$$TRACE_BASE" ]; then \
			echo "[WARNING] Trace directory for $(BENCH_NAME) not found. Skipping this benchmark for $$target_folder..."; \
			echo "N/A" >> "$$CSV_FILE"; \
			continue; \
		fi; \
		\
		WINDOW_DIRS=$$(find $$TRACE_BASE -mindepth 1 -maxdepth 1 -type d | sort); \
		for w in $$WINDOW_DIRS; do \
			WIN_NAME=$$(basename $$w); \
			WIN_IDX=$$(echo $$WIN_NAME | awk -F'_' '{print $$2}' | sed 's/^0*\([0-9]\)/\1/'); \
			LINE=$$(awk '$$2=='"$$WIN_IDX"' {print}' $(TRACE_DIR)/$(BENCH_NAME)/simpoints/opt.w.lpt0.99); \
			WEIGHT=$$(echo $$LINE | awk '{print $$1}'); \
			WIN_FINAL="$${WIN_NAME}_$${WEIGHT}"; \
			BP_FILE=$(SIM_OUT)/$$target_folder/$(BENCH_NAME)/$$WIN_FINAL/bp.stat.0.out; \
			\
			if [ -f "$$BP_FILE" ]; then \
				TOTAL_WEIGHT=$$(echo "scale=7; $$TOTAL_WEIGHT + $$WEIGHT" | bc -l); \
				\
				IPC=$$(grep "Periodic:" "$$BP_FILE" | awk '{print $$NF}'); \
				if [ -z "$$IPC" ]; then IPC=0; fi; \
				WEIGHTED_IPC_CONTRIBUTION=$$(echo "scale=7; $$WEIGHT * $$IPC" | bc -l); \
				TOTAL_WEIGHTED_IPC=$$(echo "scale=7; $$TOTAL_WEIGHTED_IPC + $$WEIGHTED_IPC_CONTRIBUTION" | bc -l); \
				\
				MPKI=$$(grep "CBR_ON_PATH_MISPREDICT_PER1000INST" "$$BP_FILE" | awk '{print $$5}'); \
				if [ -z "$$MPKI" ]; then MPKI=0; fi; \
				WEIGHTED_MPKI_CONTRIBUTION=$$(echo "scale=7; $$WEIGHT * $$MPKI" | bc -l); \
				TOTAL_WEIGHTED_MPKI=$$(echo "scale=7; $$TOTAL_WEIGHTED_MPKI + $$WEIGHTED_MPKI_CONTRIBUTION" | bc -l); \
				\
				printf "%-20s %15.7f %15.5f %15.4f\n" "$$WIN_NAME" "$$WEIGHT" "$$IPC" "$$MPKI" >> "$$CSV_FILE"; \
			else \
				echo "[WARNING] bp.stat.0.out not found for $$WIN_FINAL. Skipping..."; \
			fi \
		done; \
		\
		printf "%-20s %15.7f %15.5f %15.4f\n" "TOTAL" "$$TOTAL_WEIGHT" "$$TOTAL_WEIGHTED_IPC" "$$TOTAL_WEIGHTED_MPKI" >> "$$CSV_FILE"; \
	done
	@echo "--- All CSV files created successfully ---"

# ===================== Cleanup =====================
clean_outputs:
	rm -rf $(SIM_OUT)

clean: clean_outputs
	find . -type f ! -name '*.cpp' ! -name 'Makefile' ! -name '*.py' \
	! -name '*.in' ! -name '*.c' ! -name '*.sh' ! -name '*.bash' \
	! -name '*.md' -exec rm -f {} +
	rm -rf $(TRACE_DIR)

# ===================== 다중 BENCH 실행 =====================
JOBS ?= $(shell nproc)

# 순차 실행
run-all:
	@for bench in $(BENCH_LIST); do \
		$(MAKE) all BENCH_NAME=$$bench; \
	done

trace-all:
	@for bench in $(BENCH_LIST); do \
		$(MAKE) trace-simpoint-via-python BENCH_NAME=$$bench; \
	done

launch-all:
	@for bench in $(BENCH_LIST); do \
		$(MAKE) launch-trace BENCH_NAME=$$bench; \
	done

trace-all-parallel:
	@echo "[DEBUG] Starting parallel SimPoint tracing for all benchmarks (JOBS=$(JOBS))"
	@for bench in $(BENCH_LIST); do \
		echo "[DEBUG] Launching trace-simpoint-via-python for $$bench"; \
		( \
			echo "[DEBUG][$$bench] Running Python trace script..."; \
			$(MAKE) trace-simpoint-via-python BENCH_NAME=$$bench; \
			RET=$$?; \
			if [ $$RET -eq 0 ]; then \
				echo "[DEBUG][$$bench] Completed successfully."; \
			else \
				echo "[ERROR][$$bench] Python trace failed with code $$RET"; \
			fi \
		) & \
	done
	@wait
	@echo "[DEBUG] All parallel tracing jobs finished."

launch-all-parallel:
	@echo "[DEBUG] Starting parallel Scarab launch for all benchmarks"
	@for bench in $(BENCH_LIST); do \
		echo "[DEBUG] Launching baseline and perfect runs for $$bench"; \
		( \
			echo "[DEBUG][$$bench] Running launch-trace (baseline)..."; \
			$(MAKE) launch-trace BENCH_NAME=$$bench; \
			RET=$$?; \
			if [ $$RET -eq 0 ]; then \
				echo "[DEBUG][$$bench] Baseline run finished successfully."; \
			else \
				echo "[ERROR][$$bench] Baseline run failed with code $$RET"; \
			fi \
		) & \
		( \
			echo "[DEBUG][$$bench] Running launch-trace-perfect..."; \
			$(MAKE) launch-trace-perfect BENCH_NAME=$$bench; \
			RET=$$?; \
			if [ $$RET -eq 0 ]; then \
				echo "[DEBUG][$$bench] Perfect run finished successfully."; \
			else \
				echo "[ERROR][$$bench] Perfect run failed with code $$RET"; \
			fi \
		) & \
	done
	@wait
	@echo "[DEBUG] All parallel Scarab runs finished."

# ===================== 모든 벤치마크의 CSV 파일 생성 =====================
process-all-bench-csv:
	@for bench in $(BENCH_LIST); do \
		$(MAKE) process-all-csv BENCH_NAME=$$bench; \
	done