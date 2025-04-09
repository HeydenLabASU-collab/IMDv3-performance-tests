#!/bin/bash

#SBATCH --job-name=perf_test_MD  # Job name
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

typeprod="performance"

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
# Set number of cores
TOTAL_CORES=48
MD_CORES=40
PYTHON_CORES=8
GPU_DEVICE=0
n_runs=3

# Run MD equilibration
# ..

pos_freq=0
vel_freq=0
force_freq=0
box_freq=0
freq=0

# Loop over freq values 1, 5, 50, 500
for freq in 1 5 50 500; do
    echo "Running IMDv3 MD with file/streaming I/O with freq=${freq}..."
    
    pos_freq=freq
    # vel_freq=freq
    # force_freq=freq
    # box_freq=freq
    # IMDv3 MD with File I/O
    # ..
    # copy log file into all run folders
    for i in $(seq 1 ${n_runs}); do
        cp ${LOG_FILE} output/fileio/${typeprod}/1-1-${MD_CORES}/pos_freq-${pos_freq}_vel_freq-${vel_freq}_force_freq-${force_freq}_box_freq-${box_freq}/run-${i}/${LOG_FILE}
    done

    # IMDv3 MD with streaming
    # ..
    # copy log file into all run folders
    for i in $(seq 1 ${n_runs}); do
        cp ${LOG_FILE} output/streaming/${typeprod}/1-1-${MD_CORES}/pos_freq-${pos_freq}_vel_freq-${vel_freq}_force_freq-${force_freq}_box_freq-${box_freq}/run-${i}/${LOG_FILE}
    done

done
