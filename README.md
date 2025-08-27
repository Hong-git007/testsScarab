
# Scarab Simulation Environment Setup Guide (TRACE MODE)
Version: 20250825

## Introduction
This guide details the process of setting up the Scarab simulation environment. The entire process has been tested on Ubuntu 20.04.
It is important to note that this setup uses TRACE DRIVEN MODE, not PIN EXECUTION DRIVEN MODE.

While Scarab V.1.0 did not support the TRACE FRONTEND and wrong-path execution was seemingly only available in PIN EXECUTION DRIVEN MODE, Scarab V.2.0 introduces features that enable wrong-path related research using TRACE MODE. The primary advantage of TRACE MODE is its stability, as the PIN EXECUTION DRIVEN MODE often encounters execution errors with certain benchmarks.

This setup guide is based on the methodologies found in https://github.com/litz-lab/scarab-infra and https://github.com/raffael-daltoe/Benchmarking. The process involves extracting traces using the DynamoRIO tool and then running the Scarab simulation in TRACE MODE.

Note: This guide frequently uses absolute paths due to modifications made to the automation scripts.

## Main
### 1. Install Requirements
First, update your package list and install the necessary dependencies.
 ```bash
    sudo apt-get update && \
    sudo apt-get install -y \
    python3 \
    python3-pip \
    python2 \
    git \
    sudo \
    wget \
    cmake \
    binutils \
    libunwind-dev \
    libboost-dev \
    zlib1g-dev \
    libsnappy-dev \
    liblz4-dev \
    doxygen \
    libconfig++-dev \
    vim \
    bc \
    unzip \
    zip \
    gosu \
    linux-tools-generic \
    gdb
 ```
### 2. Clone Repositories
Clone the necessary repositories. This setup uses specific forks for certain components.
```bash
# Navigate to your chosen simulator directory
# For example:
# mkdir ~/simulator && cd ~/simulator

git clone https://github.com/raffael-daltoe/Benchmarking.git
git clone https://github.com/litz-lab/scarab-infra.git

# Navigate into the Benchmarking directory and replace the testsScarab directory
cd Benchmarking
rm -rf testsScarab
git clone https://github.com/Hong-git007/testsScarab.git

# Navigate to the tools directory and clone a specific scarab fork
cd tools
git clone https://github.com/Hong-git007/scarab.git

# Clone scarab-infra into the tools directory as well
git clone https://github.com/litz-lab/scarab-infra.git

```

### 3. Setup Instrumentation and Analysis Tools
#### DynamoRIO Setup
```bash
# From inside the ~/simulator/Benchmarking/tools directory
wget https://github.com/DynamoRIO/dynamorio/releases/download/release_10.0.0/DynamoRIO-Linux-10.0.0.tar.gz
tar -xzvf DynamoRIO-Linux-10.0.0.tar.gz

# Set permissions for the library
chmod +777 DynamoRIO-Linux-10.0.0/lib64/release/libdynamorio.so
```
#### Fingerprint Client Compilation
1. Copy the fingerprint_src from scarab-infra.
```bash
# From inside the ~/simulator/Benchmarking/tools directory
cp -r scarab-infra/fingerprint_src/ ../
```
2. Modify the fingerprint client source file. Navigate to the new fingerprint_src directory and edit fingerprint_client.cpp.
* On line 20, change the segment size default value to 200000000 (200M).
```bash
// line 20
(DROPTION_SCOPE_CLIENT, "segment_size", 200000000/*200M*/, "specify the segment size",
"Specify the size of the segments whose fingerprints will be collected. Default size is 200000000(200M).");
```
* On line 293, add a print statement to confirm the segment size.
```bash
// line 293
dr_printf("The segment size: %llu\n", op_segment_size.get_value());
```
3. Build the client.
```bash
# From inside the ~/simulator/Benchmarking/tools/fingerprint_src directory
mkdir build
cd build
cmake -DDynamoRIO_DIR=$DYNAMORIO_HOME/cmake ..
make
```
4. Copy the compiled library to the DynamoRIO release directory.
```bash
# From inside the ~/simulator/Benchmarking/tools/fingerprint_src/build directory
cp libfpg.so ../../DynamoRIO-Linux-10.0.0/lib64/release/libfingerprint_client.so
```
##### Pin and SimPoint Setup
```bash
# From inside the ~/simulator/Benchmarking/tools directory
wget -nc https://software.intel.com/sites/landingpage/pintool/downloads/pin-3.15-98253-gb56e429b1-gcc-linux.tar.gz
tar -xzvf pin-3.15-98253-gb56e429b1-gcc-linux.tar.gz

git clone https://github.com/kofyou/SimPoint.3.2.git
make -C SimPoint.3.2
ln -s SimPoint.3.2/bin/simpoint ./simpoint
```

### 4. Configure Environment Variables
Add the following exports to your ~/.bashrc file. Remember to replace /home/hong with your actual home directory path.
```bash
vim ~/.bashrc
```
Add these lines to the end of the file:
```bash
export SCARAB_ENABLE_PT_MEMTRACE=1
export scarab_tool="/home/hong/simulator/Benchmarking/tools"
export DYNAMORIO_HOME="$scarab_tool/DynamoRIO-Linux-10.0.0"
export PIN_ROOT="$scarab_tool/pin-3.15-98253-gb56e429b1-gcc-linux"

# Add tool libraries to the library path
export LD_LIBRARY_PATH="$PIN_ROOT/extras/xed-intel64/lib:$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH="$PIN_ROOT/intel64/runtime/pincrt:$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH="$DYNAMORIO_HOME/lib64/release:$LD_LIBRARY_PATH"

# Add tool binaries to the execution path
export PATH="$DYNAMORIO_HOME/bin64:$PATH"
export PATH="$scarab_tool/SimPoint.3.2/bin:$PATH"
export PATH="$PIN_ROOT/intel64/bin:$PATH"
```
Apply the changes to your current session.
```bash
source ~/.bashrc
```
### 5. Compile Scarab
```bash
# Assuming you are in ~/simulator/Benchmarking/tools
cd scarab/src
make
```
### 6. Setup SPEC CPU2017 Benchmarks
1. Mount the SPEC CPU2017 ISO image.
```bash
# Example installs to /home/HDD/hong/benchmarks/SPEC17/
cd /mnt
./install.sh -d /home/HDD/hong/benchmarks/SPEC17/
```

2. Run the installation script.
```bash
# Example installs to /home/HDD/hong/benchmarks/SPEC17/
cd /mnt
./install.sh -d /home/HDD/hong/benchmarks/SPEC17/
```

3. After installation, create a configuration file for SPEC. You can use an existing .cfg file designed for Scarab.
4. Source the SPEC environment script.
```bash
# Navigate to your SPEC installation directory
cd /home/HDD/hong/benchmarks/SPEC17
source shrc
```
5. Build and run the benchmarks.
```bash
# Build and run integer and floating-point rate benchmarks
runcpu --config=your_config_file --size=ref --copies=1 --noreportable --iterations=1 intrate fprate

# To clean a previous build
runcpu --config=your_config_file --action=clobber all
```

### 7. Generate Program Descriptors for Scarab
Finally, use the provided Scarab script to extract the command lines and execution paths for the SPEC benchmarks, which generates the program_descriptor.def file.
```bash
python3 /home/hong/simulator/Benchmarking/tools/scarab/bin/checkpoint/prepare_spec_checkpoints_directory.py \
--spec17_path /home/HDD/hong/benchmarks/SPEC17 \
-c label_name-m64.0000 \
--inputs ref \
--suite spec17_rate \
-o /home/hong/simulator/Benchmarking/tools/scarab/spec2017_run_dir_rate \
-f
```
### 8. Simulation Workflow Configuration and Execution
This stage covers the final verification of script paths required to run the simulation and automates the process from trace generation to results analysis using the Makefile.
#### 8.1 Final Path Configuration
Before executing the simulation, you must confirm that all scripts and the Makefile point to the correct paths for your environment.
1. Configure and Run extract_program_info.py
* Navigate to the following path, open the extract_program_info.py script, and verify and/or modify the path settings within it.
```bash
cd /home/hong/simulator/Benchmarking/testsScarab/simpoint
```
* Once modified, execute the script to prepare the program information.
```bash
python3 extract_program_info.py
```

2. Modify the Main Makefile
* Open the Makefile located in /home/hong/simulator/Benchmarking/testsScarab and update the path and simulation-related settings to match your environment.

3. Verify Script Paths
* run_simpoint_trace.py:
  Check this script in the /home/hong/simulator/Benchmarking/testsScarab/scripts directory. If you have followed the previous steps correctly, no changes should be necessary.

* run_clustering.sh:
  Open this script located in the /home/hong/simulator/Benchmarking/testsScarab/scripts directory. On line 3, modify the source path to ensure it correctly points to the utilities.sh file.
```bash
  # Example of line 3 in the run_clustering.sh file
  source /home/hong/simulator/Benchmarking/tools/scarab-infra/scripts/utilities.sh
```
#### 8.2 Single Benchmark Execution Workflow
All commands should be executed from the /home/hong/simulator/Benchmarking/testsScarab directory. You can run the process for a specific benchmark, defined in the BENCH_LIST variable of the Makefile, by specifying it with the BENCH_NAME variable.

Step 1: Verify Configuration Variables

Before starting the full process, you can check if the variables for the simulation are set correctly using the make run command.

```bash
# Example: Verifying the configuration for the leela_17_r_ref0 benchmark
make run BENCH_NAME=leela_17_r_ref0
```

Step 2: Generate SimPoint Traces
Generate the necessary traces for the simulation using the DynamoRIO client.
```bash
# Example: Generating traces for the leela_17_r_ref0 benchmark
make trace-simpoint-via-python BENCH_NAME=leela_17_r_ref0
```

Step 3: Launch Trace-Mode Simulation
Execute the Scarab simulation using the generated traces.
```bash
# Example: Running the simulation for the leela_17_r_ref0 benchmark
make launch-trace BENCH_NAME=leela_17_r_ref0
```
* 📝 Note: If you need to change the execution arguments for the Scarab simulator, you can modify the relevant section within the Makefile.

Step 4: Process and Analyze Results
After the simulation is complete, process the resulting CSV output files to derive the final weighted IPC and MPKI values, taking into account the SimPoint weights.
```bash
# Example: Processing results for the leela_17_r_ref0 benchmark
make process-all-csv BENCH_NAME=leela_17_r_ref0
```

#### 8.3 Multiple Benchmarks Execution Workflow
The Makefile also provides targets to run the entire simulation workflow for all benchmarks defined in the BENCH_LIST variable. You can run benchmarks in parallel, utilizing multiple CPU cores to speed up the process.

* Generate All Traces in Parallel
  Sequentially generates SimPoint traces for every benchmark in BENCH_LIST.
```bash
make trace-all-parallel
```

* Launch All Simulations in Parallel
  Simultaneously runs both the baseline and perfect simulations for every benchmark.
```bash
make launch-all-parallel
```

* Process All Results
  After all benchmark simulations are complete, use the command below to process all the generated CSV result files at once. This calculates the final weighted IPC and MPKI values for every benchmark. This step runs sequentially. 
```bash
make process-all-bench-csv
```

📝 Recommended Workflow: To run the entire benchmark suite most efficiently, using the parallel execution targets is recommended. Follow this sequence:
make trace-all-parallel → make launch-all-parallel → make process-all-bench-csv.