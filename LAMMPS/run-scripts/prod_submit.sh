#!/bin/bash

#SBATCH --job-name=prod_lammps_kokkos    # Job name
#SBATCH --output=prod_lammps_%j.out      # Output file
#SBATCH --error=prod_lammps_%j.err       # Error file
#SBATCH --partition=general              # Specify partition
#SBATCH --nodes=1                        # Use one node
#SBATCH --ntasks=1                       # Run a single job
#SBATCH --cpus-per-task=48               # Total CPU cores requested
#SBATCH --gres=gpu:a100:1                # Request 1 GPU
#SBATCH -C a100_80                       # Request A100 80GB GPU
#SBATCH --time=02:30:00                  # Max job time (24 hours)
#SBATCH --exclusive                      # Get exclusive access to the node

# Load required modules
module purge
module load gcc-12.1.0-gcc-11.2.0
module load cmake/3.30.2
module load microOSU/openmpi/4.1.5/7.4-cuda
module load cuda-12.9.0-gcc-12.1.0
module load fftw-3.3.10-gcc-12.1.0
module load gsl/2.8
module load mamba

# Activate Python environment for streaming client
source activate imdclient-new

# Verify CUDA is available
CUDA_ROOT="${CUDA_HOME:-${CUDA_ROOT}}"
if [[ -z "$CUDA_ROOT" ]]; then
    echo "CUDA_ROOT is not set by the module. Exiting." >&2
    exit 1
fi

# Export required library paths
export LIBRARY_PATH=/packages/apps/spack/21/opt/spack/linux-rocky8-zen3/gcc-12.1.0/fftw-3.3.10-al4inhytbdu5b5s5ygzsie6i5g4luvid/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/packages/apps/spack/21/opt/spack/linux-rocky8-zen3/gcc-12.1.0/fftw-3.3.10-al4inhytbdu5b5s5ygzsie6i5g4luvid/lib:$LD_LIBRARY_PATH
export C_INCLUDE_PATH=/packages/apps/gsl/2.8/include:$C_INCLUDE_PATH
export LIBRARY_PATH=/packages/apps/gsl/2.8/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/packages/apps/gsl/2.8/lib:$LD_LIBRARY_PATH

echo "========================================"
echo "LAMMPS Kokkos Production Benchmark"
echo "========================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "Start: $(date)"
echo "========================================"
echo ""

# ==========================================================================
# Job Information
# ==========================================================================

submit_time=$(scontrol show job "$SLURM_JOB_ID" | grep -oP '(?<=SubmitTime=)[^ ]+' 2>/dev/null || echo "$(date '+%Y-%m-%d %H:%M:%S')")
start_time=$(scontrol show job "$SLURM_JOB_ID" | grep -oP '(?<=StartTime=)[^ ]+' 2>/dev/null || echo "N/A")
cluster_name=${SLURM_CLUSTER_NAME:-"N/A"}
n_nodes=${SLURM_JOB_NUM_NODES:-"N/A"}
node_name_list=${SLURM_NODELIST:-"N/A"}
n_gpus=$(scontrol show job "$SLURM_JOB_ID" 2>/dev/null | grep -oP 'gres\/gpu=\K[0-9]+' || echo "0")
n_gpus=${n_gpus:-0}
gpu_type=$(scontrol show job "$SLURM_JOB_ID" 2>/dev/null | grep -oP 'gres\/gpu:\K[^=]+' || echo "N/A")
gpu_id=$(nvidia-smi --query-gpu=index,name --format=csv,noheader 2>/dev/null | head -n 1 | cut -d',' -f1 || echo "0")
n_cpus=${SLURM_CPUS_PER_TASK:-"N/A"}

cpu_ids=$(grep -oP '^Cpus_allowed_list:\s*\K.+' /proc/self/status | awk -F, '{
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
}' 2>/dev/null || echo "N/A")

typeprod="performance"

COMMON_LOG=$(cat <<EOF
Job Submitted: $submit_time
Job Started: $start_time
Cluster Name: $cluster_name
Number of Nodes: $n_nodes
Node List: $node_name_list
Number of GPUs: $n_gpus
GPU Type: $gpu_type
GPU IDs: $gpu_id
Number of CPUs: $n_cpus
CPU ID List: $cpu_ids
Job Purpose: $typeprod
EOF
)

# ==========================================================================
# Configuration
# ==========================================================================

ROOT_DIR="$(pwd)/.."
RUN_SCRIPTS_DIR="$ROOT_DIR/run-scripts"
INPUT_DIR="$ROOT_DIR/input"
OUTPUT_DIR="$ROOT_DIR/output"
BIN_DIR="$ROOT_DIR/bin"
cd "$ROOT_DIR"

GPU_DEVICE=0
N_RUNS=5
LAMMPS_CORES=8 #12
PYTHON_CORES=2
MODE="kokkos"
TASKS=1
WORKERS=7 #11
USE_GPU=1

# LAMMPS_EXEC="$BIN_DIR/lmp_openmp_mpi_gpu_single_imdv3_async"
# LAMMPS_EXEC="$BIN_DIR/lmp_openmp_mpi_gpu_single_imdv3_ON_new"
LAMMPS_EXEC="$BIN_DIR/lmp_openmp_mpi_gpu_single_imdv3_ON_new_latest"
FILEIO_INPUT="$INPUT_DIR/in.chain-fileio"
FILEIO_3_INPUT="$INPUT_DIR/in.chain-fileio-3"
FILEIO_DCD_INPUT="$INPUT_DIR/in.chain-fileio-dcd"
FILEIO_XTC_INPUT="$INPUT_DIR/in.chain-fileio-xtc"
STREAMING_INPUT="$INPUT_DIR/in.chain-streaming"
STREAMING_3_INPUT="$INPUT_DIR/in.chain-streaming-3"
PYTHON_CLIENT="$INPUT_DIR/IMDv3-client.py"

# Frequency sweep
# FREQ_LIST=(1 5 8 50 500 5000 50000)
FREQ_LIST=(5000 500 50 8 5 1)
# FREQ_LIST=(5000)

echo "Configuration: GPU=$USE_GPU, Mode=$MODE, LAMMPS cores=$LAMMPS_CORES, Python cores=$PYTHON_CORES"
echo "Frequencies to test: ${FREQ_LIST[@]}"
echo ""

# ==========================================================================
# Production Benchmarks
# ==========================================================================

for freq in "${FREQ_LIST[@]}"; do
    echo "========================================"
    echo "Running production: frequency=$freq"
    echo "========================================"

    # fileio: positions only
    echo "Running fileio (positions only) at frequency=$freq"
    "$RUN_SCRIPTS_DIR/run_fileio.sh" "$LAMMPS_CORES" "$GPU_DEVICE" "$N_RUNS" \
        "$typeprod" "$COMMON_LOG" "$freq" 0 0 0 \
        "$MODE" "$TASKS" "$WORKERS" "$LAMMPS_EXEC" "$USE_GPU" "$FILEIO_INPUT" "fileio"

#     # fileio-3: positions + velocities + forces
#     # echo "Running fileio-3 (positions + velocities + forces) at frequency=$freq"
#     # "$RUN_SCRIPTS_DIR/run_fileio.sh" "$LAMMPS_CORES" "$GPU_DEVICE" "$N_RUNS" \
#     #     "$typeprod" "$COMMON_LOG" "$freq" "$freq" "$freq" 0 \
#     #     "$MODE" "$TASKS" "$WORKERS" "$LAMMPS_EXEC" "$USE_GPU" "$FILEIO_3_INPUT" "fileio-3"

#     # # xtc: positions only
#     # echo "Running xtc (positions only) at frequency=$freq"
#     # "$RUN_SCRIPTS_DIR/run_fileio.sh" "$LAMMPS_CORES" "$GPU_DEVICE" "$N_RUNS" \
#     #     "$typeprod" "$COMMON_LOG" "$freq" 0 0 0 \
#     #     "$MODE" "$TASKS" "$WORKERS" "$LAMMPS_EXEC" "$USE_GPU" "$FILEIO_XTC_INPUT" "fileio-xtc"

#     # # dcd: positions only
#     # echo "Running dcd (positions only) at frequency=$freq"
#     # "$RUN_SCRIPTS_DIR/run_fileio.sh" "$LAMMPS_CORES" "$GPU_DEVICE" "$N_RUNS" \
#     #     "$typeprod" "$COMMON_LOG" "$freq" 0 0 0 \
#     #     "$MODE" "$TASKS" "$WORKERS" "$LAMMPS_EXEC" "$USE_GPU" "$FILEIO_DCD_INPUT" "fileio-dcd"

done

# for freq in "${FREQ_LIST[@]}"; do
#     echo "========================================"
#     echo "Running production: frequency=$freq"
#     echo "========================================"

#     # streaming: positions only
#     echo "Running streaming (positions only) at frequency=$freq"
#     "$RUN_SCRIPTS_DIR/run_streaming-new.sh" "$LAMMPS_CORES" "$GPU_DEVICE" "$PYTHON_CORES" "$N_RUNS" \
#         "$typeprod" "$COMMON_LOG" "$freq" 0 0 0 \
#         "$MODE" "$TASKS" "$WORKERS" "$LAMMPS_EXEC" "$USE_GPU" "$STREAMING_INPUT" "$PYTHON_CLIENT" "streaming"

#     # streaming-3: positions + velocities + forces
#     echo "Running streaming-3 (positions + velocities + forces) at frequency=$freq"
#     "$RUN_SCRIPTS_DIR/run_streaming-new.sh" "$LAMMPS_CORES" "$GPU_DEVICE" "$PYTHON_CORES" "$N_RUNS" \
#         "$typeprod" "$COMMON_LOG" "$freq" "$freq" "$freq" 0 \
#         "$MODE" "$TASKS" "$WORKERS" "$LAMMPS_EXEC" "$USE_GPU" "$STREAMING_3_INPUT" "$PYTHON_CLIENT" "streaming-3"

#     echo ""
# done

echo "========================================"
echo "LAMMPS Kokkos production sweep complete!"
echo "========================================"
