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

# Log file path (this file will be created in the working directory)
LOG_FILE="job_info.log"

# Retrieve job submission time from Slurm using scontrol.
# Note: This depends on your Slurm version and configuration.
submit_time=$(scontrol show job $SLURM_JOB_ID | grep -oP '(?<=SubmitTime=)[^ ]+')
# Fallback to current time if submit_time is not found
[ -z "$submit_time" ] && submit_time=$(date "+%Y-%m-%d %H:%M:%S")
# Start time
start_time=$(scontrol show job $SLURM_JOB_ID | grep -oP '(?<=StartTime=)[^ ]+')
# Get Cluster Name; if not defined, default to "Unknown Cluster"
cluster_name=${SLURM_CLUSTER_NAME:-"NA"}
# Get the Node Name List allocated for this job
node_name_list=${SLURM_NODELIST:-"NA"}
# Number of GPUs requested.
# Some systems may provide SLURM_GPUS or you might have to parse SLURM gres settings.
n_gpus=$(scontrol show job $SLURM_JOB_ID | grep -oP 'gres\/gpu=\K[0-9]+')
n_gpus=${n_gpus:-0}
# Type of GPU requested
gpu_type=$(scontrol show job 24461568 | grep -oP 'gres\/gpu:\K[^=]+')
gpu_type=${gpu_type:-"NA"}
# GPU ID
gpu_id=$(nvidia-smi --query-gpu=index,name --format=csv,noheader | grep -i "$gpu_type" | head -n 1 | cut -d',' -f1)
# Requested number of CPUs per task
n_cpus=${SLURM_CPUS_PER_TASK:-"NA"}
# CPU ID list
cpu_ids=$(grep -oP '^Cpus_allowed_list:\s*\K.+' /proc/self/status)
# type of production
typeprod="optimization"
# Write all information to the log file slurm jobnumber.log
LOG_FILE="job_info_${SLURM_JOB_ID}.log"
{
  echo "Job Submitted: $submit_time"
  echo "Job Started: $start_time"
  echo "Cluster Name: $cluster_name"
  echo "Node Name List: $node_name_list"
  echo "Requested number of GPUs: $gpu_req"
  echo "Requested GPU Type: $gpu_type"
  echo "GPU IDs: $gpu_id"
  echo "Requested number of CPUs: $cpu_req"
  echo "CPU IDs: $cpu_ids"
  echo "Purpose of the job: $typeprod"
} > $LOG_FILE
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
    ./run/prod_vanilla.sh ${NAMD_CORES} ${GPU_DEVICE} ${n_runs} ${typeprod}
    # copy log file into all run folders
    for i in $(seq 1 ${n_runs}); do
        cp ${LOG_FILE} output/vanilla/${typeprod}/1-1-${NAMD_CORES}/run-${i}/${LOG_FILE}
    done

    # Run IMDv3 NAMD production
    ./run/prod_imdv3.sh ${NAMD_CORES} ${GPU_DEVICE} ${n_runs} ${typeprod}
    # copy log file into all run folders
    for i in $(seq 1 ${n_runs}); do
        cp ${LOG_FILE} output/imdv3/${typeprod}/1-1-${NAMD_CORES}/run-${i}/${LOG_FILE}
    done
    
    # Run IMDv3 NAMD with File I/O production
    # ./run/prod_fileio.sh ${NAMD_CORES} ${GPU_DEVICE} ${n_runs}
    
    # Run IMDv3 NAMD with Streaming production (with Python client)
    # ./run/prod_streaming.sh ${NAMD_CORES} ${GPU_DEVICE} ${PYTHON_CORES} ${n_runs}
done
