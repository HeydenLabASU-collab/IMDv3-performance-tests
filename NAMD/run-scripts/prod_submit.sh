#!/bin/bash

#SBATCH --job-name=perf_test_NAMD  # Job name
#SBATCH --output=perf_test_%j.out    # Output file
#SBATCH --error=perf_test_%j.err     # Error file
#SBATCH --partition=general         # Specify partition
#SBATCH --nodes=1                   # Use one node
#SBATCH --ntasks=1                  # Run a single job
#SBATCH --cpus-per-task=48          # Total CPU cores requested
#SBATCH --gres=gpu:a100:1                # Request 1 GPU
#SBATCH --time=06:00:00           # Max job time (22 hours)
#SBATCH --exclusive                 # Get exclusive access to the node

module purge
module load gcc-12.1.0-gcc-11.2.0
module load cmake/3.30.2
module load microOSU/openmpi/4.1.5/7.4-cuda
module load cuda-12.9.0-gcc-12.1.0
module load mamba

CUDA_ROOT="${CUDA_HOME:-${CUDA_ROOT}}"
if [[ -z "$CUDA_ROOT" ]]; then
    echo "CUDA_ROOT is not set by the module. Exiting." >&2
    exit 1
fi

source activate imdclient-new

# Retrieve job submission time from Slurm using scontrol.
# Note: This depends on your Slurm version and configuration.
submit_time=$(scontrol show job $SLURM_JOB_ID | grep -oP '(?<=SubmitTime=)[^ ]+')
# Fallback to current time if submit_time is not found
[ -z "$submit_time" ] && submit_time=$(date "+%Y-%m-%d %H:%M:%S")
# Start time
start_time=$(scontrol show job $SLURM_JOB_ID | grep -oP '(?<=StartTime=)[^ ]+')
# Get Cluster Name; if not defined, default to "Unknown Cluster"
cluster_name=${SLURM_CLUSTER_NAME:-"N/A"}
# Get the number of nodes requested for the job
n_nodes=${SLURM_JOB_NUM_NODES:-"N/A"}
# Get the Node Name List allocated for this job
node_name_list=${SLURM_NODELIST:-"N/A"}
# Number of GPUs requested.
# Some systems may provide SLURM_GPUS or you might have to parse SLURM gres settings.
n_gpus=$(scontrol show job $SLURM_JOB_ID | grep -oP 'gres\/gpu=\K[0-9]+')
n_gpus=${n_gpus:-0}
# Type of GPU requested
gpu_type=$(scontrol show job "$SLURM_JOB_ID" | grep -oP 'gres\/gpu:\K[^=]+')
gpu_type=${gpu_type:-"N/A"}
# GPU ID
gpu_id=$(nvidia-smi --query-gpu=index,name --format=csv,noheader | grep -i "$gpu_type" | head -n 1 | cut -d',' -f1)
# Requested number of CPUs per task
n_cpus=${SLURM_CPUS_PER_TASK:-"N/A"}
# CPU ID list as semi colon seperated list
cpu_ids=$(
  grep -oP '^Cpus_allowed_list:\s*\K.+' /proc/self/status |
  awk -F, '
    {
      sep = ""
      for (i = 1; i <= NF; i++) {
        if ($i ~ /-/) {
          split($i, r, "-")
          for (j = r[1]; j <= r[2]; j++) {
            printf "%s%d", sep, j
            sep = ";"
          }
        } else {
          printf "%s%s", sep, $i
          sep = ";"
        }
      }
    }
  '
)
# type of production
typeprod="performance"
# Write all information to the log file slurm jobnumber.log
COMMON_LOG=$(cat <<EOF
Job Submitted: $submit_time
Job Started: $start_time
Cluster Name: $cluster_name
Number of Nodes requested: $n_nodes
Node Name List: $node_name_list
Number of GPUs requested: $n_gpus
GPU type requested: $gpu_type
GPU IDs list: $gpu_id
Number of CPUs requested: $n_cpus
CPU ID list: $cpu_ids
Purpose of the job: $typeprod
EOF
)
# Set number of cores
TOTAL_CORES=48
NAMD_CORES=46
PYTHON_CORES=2
GPU_DEVICE=0
n_runs=5
MODE="mpi_smp"
TASKS=1
WORKERS=45
USE_GPU=1

# Resolve root directories from this script location
ROOT_DIR="$(pwd)/.."
RUN_SCRIPTS_DIR="$ROOT_DIR/run-scripts"
BIN_DIR="$ROOT_DIR/bin"
# IMDV3_EXEC="$BIN_DIR/namd_mpi_smp_gpuresident_imdv3"
IMDV3_EXEC="$BIN_DIR/namd_mpi_smp_gpuresident_gpures-new"
FILEIO_INPUT="$ROOT_DIR/input/step5_production_fileio.inp"
FILEIO_3_INPUT="$ROOT_DIR/input/step5_production_fileio-3.inp"
STREAMING_INPUT="$ROOT_DIR/input/step5_production_streaming.inp"
STREAMING_3_INPUT="$ROOT_DIR/input/step5_production_streaming-3.inp"
STREAMING_PY_INPUT="$ROOT_DIR/input/IMDv3-client.py"
cd "$ROOT_DIR"

# Run NAMD equilibration once (vanilla reference)
EQUIL_OUT="$ROOT_DIR/output/vanilla/performance/equil/1-0-40/run-1/step4_equilibration.out"
if [[ ! -f "$EQUIL_OUT" ]] || ! grep -q "End of program" "$EQUIL_OUT"; then
  echo "Running equilibration..."
  "$RUN_SCRIPTS_DIR/equi.sh" 40 "$GPU_DEVICE" "$COMMON_LOG" \
    "$BIN_DIR/namd_multicore_gpuresident_vanilla" "$ROOT_DIR/input/step4_equilibration.inp"
else
  echo "Equilibration already completed. Skipping..."
fi

# Frequency sweep for production
# FREQ_LIST=(5000 500 50 8 5 1)
FREQ_LIST=(1)
# FREQ_LIST=(1)
# FREQ_LIST=(1)

for freq in "${FREQ_LIST[@]}"; do
  echo "Running production frequency=${freq} with ${USE_GPU}-${TASKS}-${WORKERS} configuration..."

  # freq is not eq 1
  # if (("$freq" != 1)); then
    # fileio: positions only
  # "$RUN_SCRIPTS_DIR/run_fileio.sh" "$NAMD_CORES" "$GPU_DEVICE" "$n_runs" \
  #   "$typeprod" "$COMMON_LOG" "$freq" 0 0 0 \
  #   "$MODE" "$TASKS" "$WORKERS" "$IMDV3_EXEC" "$USE_GPU" "$FILEIO_INPUT" "fileio"
  # # fi

  # fileio-3: positions + velocities + forces
  # "$RUN_SCRIPTS_DIR/run_fileio.sh" "$NAMD_CORES" "$GPU_DEVICE" "$n_runs" \
  #   "$typeprod" "$COMMON_LOG" "$freq" "$freq" "$freq" 0 \
  #   "$MODE" "$TASKS" "$WORKERS" "$IMDV3_EXEC" "$USE_GPU" "$FILEIO_3_INPUT" "fileio-3"

  # # if freq is not eq 8
  # if (("$freq" != 5)); then
  #   # streaming: positions only
  # # streaming: positions only
  #   "$RUN_SCRIPTS_DIR/run_streaming-new.sh" "$NAMD_CORES" "$GPU_DEVICE" "$PYTHON_CORES" "$n_runs" \
  #     "$typeprod" "$COMMON_LOG" "$freq" 0 0 0 \
  #     "$MODE" "$TASKS" "$WORKERS" "$IMDV3_EXEC" "$USE_GPU" "$STREAMING_INPUT" "$STREAMING_PY_INPUT" "streaming"
  # fi

  # streaming-3: positions + velocities + forces
  "$RUN_SCRIPTS_DIR/run_streaming-new.sh" "$NAMD_CORES" "$GPU_DEVICE" "$PYTHON_CORES" "$n_runs" \
    "$typeprod" "$COMMON_LOG" "$freq" "$freq" "$freq" 0 \
    "$MODE" "$TASKS" "$WORKERS" "$IMDV3_EXEC" "$USE_GPU" "$STREAMING_3_INPUT" "$STREAMING_PY_INPUT" "streaming-3"
done
