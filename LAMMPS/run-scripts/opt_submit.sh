#!/usr/bin/env bash

#SBATCH --job-name=opt_lammps_kokkos    # Job name
#SBATCH --output=opt_lammps_%j.out      # Output file
#SBATCH --error=opt_lammps_%j.err       # Error file
#SBATCH --partition=general             # Specify partition
#SBATCH --nodes=1                       # Use one node
#SBATCH --ntasks=1                      # Run a single job
#SBATCH --cpus-per-task=48              # Total CPU cores requested
#SBATCH --gres=gpu:a100:1               # Request 1 GPU
#SBATCH -C a100_80                       # Request A100 80GB GPU
#SBATCH --time=00:30:00                 # Max job time (12 hours)
#SBATCH --exclusive                     # Get exclusive access to the node

# Load required modules
module purge
module load gcc-12.1.0-gcc-11.2.0
module load cmake/3.30.2
module load microOSU/openmpi/4.1.5/7.4-cuda
module load cuda-12.9.0-gcc-12.1.0
module load fftw-3.3.10-gcc-12.1.0
module load gsl/2.8

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
echo "LAMMPS Kokkos Optimization Benchmark"
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

typeprod="optimization"

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
INPUT_FILE="$INPUT_DIR/in.chain-opt"
cd "$ROOT_DIR"

GPU_DEVICE=0
N_RUNS=1
CORE_LIST=(2 4 6 8 12 24 36 40 46 48)
# CORE_LIST=(12)

CPU_LIST=$(grep -oP '^Cpus_allowed_list:\s*\K.+' /proc/self/status)
echo "Available CPUs: $CPU_LIST"
echo ""

expand_cpu_list() {
    local list="$1"
    local expanded=()
    IFS=',' read -ra ranges <<< "$list"
    for range in "${ranges[@]}"; do
        if [[ "$range" == *"-"* ]]; then
            IFS='-' read -r start end <<< "$range"
            for (( i=start; i<=end; i++ )); do
                expanded+=("$i")
            done
        else
            expanded+=("$range")
        fi
    done
    echo "${expanded[@]}"
}

AVAILABLE_CPUS=($(expand_cpu_list "$CPU_LIST"))
echo "Total available cores: ${#AVAILABLE_CPUS[@]}"
echo ""

# ==========================================================================
# Run Optimization for Vanilla and IMDv3
# ==========================================================================

VERSIONS=("vanilla" "imdv3")
# VERSIONS=("vanilla")

for VERSION in "${VERSIONS[@]}"; do
    echo "========================================"
    echo "Optimization Benchmarks: $VERSION"
    echo "========================================"

    # Multicore GPU (1 MPI task, N threads)
    for cores in "${CORE_LIST[@]}"; do
        if [ $cores -gt ${#AVAILABLE_CPUS[@]} ]; then
            continue
        fi
        echo "Running $VERSION: multicore with $cores cores, GPU enabled"
        # "$RUN_SCRIPTS_DIR/run_${VERSION}.sh" "$cores" "$GPU_DEVICE" "$N_RUNS" "$typeprod" "$COMMON_LOG" \
        #     kokkos "$BIN_DIR/lmp_openmp_mpi_gpu_single_${VERSION}" 1 "$INPUT_FILE"
        "$RUN_SCRIPTS_DIR/run_${VERSION}.sh" "$cores" "$GPU_DEVICE" "$N_RUNS" "$typeprod" "$COMMON_LOG" \
            kokkos "$BIN_DIR/lmp_openmp_mpi_gpu_single_${VERSION}_ON_new_latest" 1 "$INPUT_FILE"
    done

    echo ""
done

echo "========================================"
echo "LAMMPS Kokkos optimization complete!"
echo "========================================"
