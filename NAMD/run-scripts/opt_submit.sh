#!/bin/bash

#SBATCH --job-name=perf_test_NAMD_2      # Job name
#SBATCH --output=perf_test_%j.out      # Output file
#SBATCH --error=perf_test_%j.err       # Error file
#SBATCH --partition=general               # Specify partition
#SBATCH --nodes=1                      # Use one node
#SBATCH --exclude=sg031                     # Exclude specific node if needed
#SBATCH --ntasks=1                     # Run a single job
#SBATCH --cpus-per-task=48             # Total CPU cores requested
#SBATCH -G a100:1                      # Request 1 GPU
#SBATCH --time=1:45:00                # Max job time (23 hours)
#SBATCH --exclusive                    # Optional: exclusive access if desired

module purge
module load gcc-12.1.0-gcc-11.2.0
module load cmake/3.30.2
module load microOSU/openmpi/4.1.5/7.4-cuda
module load cuda-12.9.0-gcc-12.1.0

CUDA_ROOT="${CUDA_HOME:-${CUDA_ROOT}}"
if [[ -z "$CUDA_ROOT" ]]; then
    echo "CUDA_ROOT is not set by the module. Exiting." >&2
    exit 1
fi

echo "========================================"
echo "NAMD Configuration Benchmark"
echo "========================================"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "Start: $(date)"
echo "========================================"
echo ""

# ==========================================================================
# Job Information
# ==========================================================================

submit_time=$(scontrol show job "$SLURM_JOB_ID" | grep -oP '(?<=SubmitTime=)[^ ]+')
[ -z "$submit_time" ] && submit_time=$(date "+%Y-%m-%d %H:%M:%S")
start_time=$(scontrol show job "$SLURM_JOB_ID" | grep -oP '(?<=StartTime=)[^ ]+')

cluster_name=${SLURM_CLUSTER_NAME:-"N/A"}
n_nodes=${SLURM_JOB_NUM_NODES:-"N/A"}
node_name_list=${SLURM_NODELIST:-"N/A"}

n_gpus=$(scontrol show job "$SLURM_JOB_ID" | grep -oP 'gres\/gpu=\K[0-9]+')
n_gpus=${n_gpus:-0}
gpu_type=$(scontrol show job "$SLURM_JOB_ID" | grep -oP 'gres\/gpu:\K[^=]+')
gpu_type=${gpu_type:-"N/A"}
gpu_id=$(nvidia-smi --query-gpu=index,name --format=csv,noheader | head -n 1 | cut -d',' -f1)

n_cpus=${SLURM_CPUS_PER_TASK:-"N/A"}
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

typeprod="optimization"

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
N_RUNS=1
EQUIL_CORES=40
CORE_LIST=(2 4 8 12 24 36 40) # 46 48)
MPI_TOTALS=(2 4 8 12 24 36 40) # 46 48)

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
# Run Equilibration (once for vanilla, shared across all)
# ==========================================================================

EQUIL_OUT="output/vanilla/performance/equil/1-1-${EQUIL_CORES}/run-1"
if [ ! -f "$EQUIL_OUT/step4_equilibration.out" ] || ! grep -q "End of program" "$EQUIL_OUT/step4_equilibration.out"; then
    echo "========================================"
    echo "Running Equilibration (vanilla)"
    echo "========================================"
    "$RUN_SCRIPTS_DIR/equi.sh" "$EQUIL_CORES" "$GPU_DEVICE" "$COMMON_LOG" "$BIN_DIR/namd_multicore_gpuresident_vanilla" "$INPUT_DIR/step4_equilibration.inp"
else
    echo "✓ Equilibration already exists"
fi
echo ""

# ==========================================================================
# Production Benchmarks
# ==========================================================================

for VERSION in vanilla; do # vanilla imdv3 main; do
    echo "========================================"
    echo "Production Benchmarks: $VERSION"
    echo "========================================"

    # # 1) Multicore (CPU only)
    # for cores in "${CORE_LIST[@]}"; do
    #     if [ $cores -gt ${#AVAILABLE_CPUS[@]} ]; then
    #         continue
    #     fi
    #     "$RUN_SCRIPTS_DIR/run_${VERSION}.sh" "$cores" "$GPU_DEVICE" "$N_RUNS" "${typeprod}" "$COMMON_LOG" \
    #         multicore 0 0 "$BIN_DIR/namd_multicore_${VERSION}" 0 $INPUT_DIR/step5_production_${VERSION}.inp
    # done

    # # 2) MPI+SMP (CPU only)
    # for total in "${MPI_TOTALS[@]}"; do
    #     for tasks in $(seq 1 "$total"); do
    #         if (( total % tasks != 0 )); then
    #             continue
    #         fi
    #         workers=$((total / tasks - 1))
    #         if (( workers < 0 )); then
    #             continue
    #         fi
    #         "$RUN_SCRIPTS_DIR/run_${VERSION}.sh" "$total" "$GPU_DEVICE" "$N_RUNS" "${typeprod}" "$COMMON_LOG" \
    #             mpi_smp "$tasks" "$workers" "$BIN_DIR/namd_mpi_smp_${VERSION}" 0 $INPUT_DIR/step5_production_${VERSION}.inp
    #     done
    # done

    # # 3) Multicore GPU resident
    # for cores in "${CORE_LIST[@]}"; do
    #     if [ $cores -gt ${#AVAILABLE_CPUS[@]} ]; then
    #         continue
    #     fi
    #     "$RUN_SCRIPTS_DIR/run_${VERSION}.sh" "$cores" "$GPU_DEVICE" "$N_RUNS" "${typeprod}" "$COMMON_LOG" \
    #         multicore_gpuresident 0 0 "$BIN_DIR/namd_multicore_gpuresident_${VERSION}" 1 $INPUT_DIR/step5_production_${VERSION}.inp
    # done

    # 4) MPI+SMP GPU resident
    # if version is main then MPI_TOTALS else just 46 and 48
    # if [[ "$VERSION" == "main" ]]; then
    #     MPI_TOTALS=(46 48 2 4 8 12 24 36 40)
    # else
    #     MPI_TOTALS=(46 48)
    # fi
    for total in "${MPI_TOTALS[@]}"; do
        # tasks must only be 1
        # for tasks in $(seq 1 "$total"); do
        for tasks in 1; do
            if (( total % tasks != 0 )); then
                continue
            fi
            workers=$((total / tasks - 1))
            if (( workers < 0 )); then
                continue
            fi
            "$RUN_SCRIPTS_DIR/run_${VERSION}.sh" "$total" "$GPU_DEVICE" "$N_RUNS" "${typeprod}" "$COMMON_LOG" \
                mpi_smp_gpuresident "$tasks" "$workers" "$BIN_DIR/namd_mpi_smp_gpuresident_${VERSION}" 1 $INPUT_DIR/step5_production_${VERSION}.inp
        done
    done

    echo ""
done

# for VERSION in vanilla imdv3; do
#     echo "========================================"
#     echo "Production Benchmarks: $VERSION"
#     echo "========================================"


#     # 3) Multicore GPU resident
#     for cores in "${CORE_LIST[@]}"; do
#         if [ $cores -gt ${#AVAILABLE_CPUS[@]} ]; then
#             continue
#         fi
#         "$RUN_SCRIPTS_DIR/run_${VERSION}.sh" "$cores" "$GPU_DEVICE" "$N_RUNS" "${typeprod}" "$COMMON_LOG" \
#             multicore_gpuresident 0 0 "$BIN_DIR/namd_multicore_gpuresident_${VERSION}" 1 $INPUT_DIR/step5_production_${VERSION}.inp
#     done

#     echo ""
# done