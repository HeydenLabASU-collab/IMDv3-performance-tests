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
./run/equi.sh ${NAMD_CORES} ${GPU_DEVICE}

# Run NAMD production
# vanilla NAMD
./run/prod_vanilla.sh ${NAMD_CORES} ${GPU_DEVICE} ${n_runs}

# IMDv3 NAMD
./run/prod_imdv3.sh ${NAMD_CORES} ${GPU_DEVICE} ${n_runs}

# IMDv3 NAMD with File I/O
./run/prod_imdv3_fileio.sh ${NAMD_CORES} ${GPU_DEVICE} ${n_runs}

# IMDv3 NAMD with streaming
./run/prod_imdv3_streaming.sh ${NAMD_CORES} ${GPU_DEVICE} ${PYTHON_CORES} ${n_runs}
