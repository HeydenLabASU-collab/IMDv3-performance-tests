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

# Retrieve job submission time from Slurm using scontrol.
# Note: This depends on your Slurm version and configuration.
submit_time=$(scontrol show job $SLURM_JOB_ID | grep -oP '(?<=SubmitTime=)[^ ]+')
# Fallback to current time if submit_time is not found
[ -z "$submit_time" ] && submit_time=$(date "+%Y-%m-%d %H:%M:%S")
# Start time
start_time=$(scontrol show job $SLURM_JOB_ID | grep -oP '(?<=StartTime=)[^ ]+')
# Get Cluster Name; if not defined, default to "Unknown Cluster"
cluster_name=${SLURM_CLUSTER_NAME:-"NA"}
# Get the Node list allocated for this job
node_list=${SLURM_NODELIST:-"NA"}
# Number of GPUs requested.
# Some systems may provide SLURM_GPUS or you might have to parse SLURM gres settings.
n_gpus=$(scontrol show job $SLURM_JOB_ID | grep -oP 'gres\/gpu=\K[0-9]+')
n_gpus=${n_gpus:-0}
# Type of GPU requested
gpu_type=$(scontrol show job 24461568 | grep -oP 'gres\/gpu:\K[^=]+')
gpu_type=${gpu_type:-"NA"}
# GPU ID
gpu_id=0
# Requested number of CPUs per task
n_cpus=${SLURM_CPUS_PER_TASK:-"NA"}
# CPU ID list
cpu_ids=$(grep -oP '^Cpus_allowed_list:\s*\K.+' /proc/self/status)

# Write all information to the log file slurm jobnumber.log
LOG_FILE="job_info_${SLURM_JOB_ID}.log"
{
  echo "Job Submitted: $submit_time"
  echo "Job Started: $start_time"
  echo "Cluster Name: $cluster_name"
  echo "Node List: $node_list"
  echo "Requested number of GPUs: $gpu_req"
  echo "Requested GPU Type: $gpu_type"
  echo "GPU IDs: $gpu_id"
  echo "Requested number of CPUs: $cpu_req"
  echo "CPU IDs: $cpu_ids"
} > $LOG_FILE
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
    # copy log file into folders
    cp ${LOG_FILE} output/fileio/${typeprod}/1-1-${NAMD_CORES}/pos_freq-${pos_freq}_vel_freq-${vel_freq}_force_freq-${force_freq}_box_freq-${box_freq}/${LOG_FILE}
    

    # IMDv3 NAMD with streaming
    ./run/prod_streaming.sh ${NAMD_CORES} ${GPU_DEVICE} ${PYTHON_CORES} ${n_runs} ${pos_freq} ${vel_freq} ${force_freq} ${box_freq} ${typeprod}
    # copy log file into folders
    cp ${LOG_FILE} output/streaming/${typeprod}/1-1-${NAMD_CORES}/pos_freq-${pos_freq}_vel_freq-${vel_freq}_force_freq-${force_freq}_box_freq-${box_freq}/${LOG_FILE}
done
