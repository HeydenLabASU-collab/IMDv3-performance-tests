#!/bin/bash

#SBATCH --job-name=perf_test_NAMD  # Job name
#SBATCH --output=perf_test_%j.out    # Output file
#SBATCH --error=perf_test_%j.err     # Error file
#SBATCH --partition=general         # Specify partition
#SBATCH --nodes=1                   # Use one node
#SBATCH --ntasks=1                  # Run a single job
#SBATCH --cpus-per-task=48          # Total CPU cores requested
#SBATCH --gres=gpu:a100:1                # Request 1 GPU
#SBATCH --time=22:00:00           # Max job time (22 hours)
#SBATCH --exclusive                 # Get exclusive access to the node

# Set number of cores
TOTAL_CORES=48
NAMD_CORES=40
PYTHON_CORES=8
GPU_DEVICE=0
n_runs=3

# Run NAMD equilibration
# check if there is a *.out file in the output/vanilla/performance/equil/*/run-1/ directory with "End of program" in it and only run if it doesn't exist
if [ ! -f output/vanilla/performance/equil/*/run-1/step4_equilibration.out ] || ! grep -q "End of program" output/vanilla/performance/equil/*/run-1/step4_equilibration.out; then
    echo "Running equilibration..."
    ./run/equi.sh ${NAMD_CORES} ${GPU_DEVICE}
else
    echo "Equilibration already completed. Skipping..."
fi

typeprod="performance"
# Run NAMD production
# vanilla NAMD
# ./run/prod_vanilla.sh ${NAMD_CORES} ${GPU_DEVICE} ${n_runs} ${typeprod}

# IMDv3 NAMD
# ./run/prod_imdv3.sh ${NAMD_CORES} ${GPU_DEVICE} ${n_runs} ${typeprod}

pos_freq=0
vel_freq=0
force_freq=0
box_freq=0
freq=0

# Loop over freq values 1, 5, 50, 500
for freq in 1 5 50 500; do
    echo "Running IMDv3 NAMD with File I/O with freq=${freq}..."
    
    pos_freq=freq
    # vel_freq=freq
    # force_freq=freq
    # box_freq=freq
    # IMDv3 NAMD with File I/O
    ./run/prod_fileio.sh ${NAMD_CORES} ${GPU_DEVICE} ${n_runs} ${pos_freq} ${vel_freq} ${force_freq} ${box_freq} ${typeprod}

    # IMDv3 NAMD with streaming
    ./run/prod_streaming.sh ${NAMD_CORES} ${GPU_DEVICE} ${PYTHON_CORES} ${n_runs} ${pos_freq} ${vel_freq} ${force_freq} ${box_freq} ${typeprod}
done
