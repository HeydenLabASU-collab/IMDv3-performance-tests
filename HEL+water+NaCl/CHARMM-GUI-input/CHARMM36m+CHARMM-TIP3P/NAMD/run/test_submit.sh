#!/bin/bash

#SBATCH --job-name=perf_test_NAMD      # Job name
#SBATCH --output=perf_test_%j.out        # Output file
#SBATCH --error=perf_test_%j.err         # Error file
#SBATCH --partition=general              # Specify partition
#SBATCH --nodes=1                        # Use one node
#SBATCH --ntasks=1                       # Run a single job
#SBATCH --cpus-per-task=48               # Total CPU cores requested
#SBATCH --gres=gpu:a100:1                # Request 1 GPU
#SBATCH --time=22:00:00                  # Max job time (22 hours)
#SBATCH --exclusive                   # Optional: exclusive access if desired

# Number of runs for each test
n_runs=3

# Set number of cores
NAMD_CORES=40
GPU_DEVICE=0
# Run NAMD equilibration
# check if there is a *.out file in the output/vanilla/performance/equil/run-1/ directory with "End of program" in it and only run if it doesn't exist
if [ ! -f output/vanilla/performance/equil/run-1/step4_equilibration.out ] || ! grep -q "End of program" output/vanilla/performance/equil/run-1/step4_equilibration.out; then
    echo "Running equilibration..."
    ./run/equi.sh ${NAMD_CORES} ${GPU_DEVICE}
else
    echo "Equilibration already completed. Skipping..."
fi

# Loop over NAMD_CORES values [10,20,30,40]
for NAMD_CORES in 6 10 12 20 24 30 36 40 48; do
    GPU_DEVICE=0
    PYTHON_CORES=2
    echo "Running tests with NAMD_CORES=${NAMD_CORES}, GPU_DEVICE=${GPU_DEVICE}, PYTHON_CORES=${PYTHON_CORES}"
    
    # Run vanilla NAMD production
    ./run/prod_vanilla.sh ${NAMD_CORES} ${GPU_DEVICE} ${n_runs}
    
    # Run IMDv3 NAMD production
    ./run/prod_imdv3.sh ${NAMD_CORES} ${GPU_DEVICE} ${n_runs}
    
    # Run IMDv3 NAMD with File I/O production
    # ./run/prod_fileio.sh ${NAMD_CORES} ${GPU_DEVICE} ${n_runs}
    
    # Run IMDv3 NAMD with Streaming production (with Python client)
    # ./run/prod_streaming.sh ${NAMD_CORES} ${GPU_DEVICE} ${PYTHON_CORES} ${n_runs}
done
