#!/usr/bin/env bash

# LAMMPS Vanilla Optimization Script
# Tests vanilla LAMMPS (no IMDv3) with Kokkos across different configurations
# Usage: ./run_vanilla_lammps.sh <n_cores> <gpu_device> <n_runs> <typeprod> <COMMON_LOG> <exec_name> <use_gpu> <input_file>

# Input parameters (Kokkos only - no MPI support)
N_CORES="${1:-2}"           # Number of CPU cores
GPU_DEVICE="${2:-0}"         # GPU device to use
N_RUNS="${3:-1}"             # Number of runs
TYPEPROD="${4:-optimization}" # Type of production
COMMON_LOG="${5:-}"          # Common log information
MODE="${6:-multicore}"       # multicore or mpi_smp
EXEC_NAME="${7:-bin/lmp_kokkos}"
USE_GPU="${8:-1}"
INPUT_FILE="${9:-input/in.chain}"

# Function to expand a CPU list
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

# Get allocated CPUs
cpu_ids=$(thisjob 2>/dev/null | grep CPU_IDs | sed -E 's/.*CPU_IDs=([^ ]+).*/\1/' || echo "")
if [[ -n "$cpu_ids" ]]; then
    allocated=($(expand_cpu_list "$cpu_ids"))
else
    if [[ -z "$SLURM_JOB_CPUS_LIST" ]]; then
        allocated=($(seq 0 $(($(nproc) - 1))))
    else
        allocated=($(expand_cpu_list "$SLURM_JOB_CPUS_LIST"))
    fi
fi

# Calculate required cores (Kokkos multicore only)
total_allocated=${#allocated[@]}
required=$N_CORES

if (( total_allocated < required )); then
    echo "Warning: Not enough allocated cores. Allocated: $total_allocated, Required: $required"
fi

# Get core list
core_list_array=("${allocated[@]:0:required}")
core_list=$(IFS=, ; echo "${core_list_array[*]}")

# Variables for file paths
opt_prefix="step_opt_vanilla"
lammps="$EXEC_NAME"
config_label="${USE_GPU}-0-${N_CORES}"
output_dir="output/vanilla/${TYPEPROD}/prod/${config_label}"
LOG_FILE="job_info_${SLURM_JOB_ID}.log"

mkdir -p "${output_dir}"

for run in $(seq 1 "$N_RUNS"); do
    echo "=========================================="
    echo "Running vanilla optimization: config=$config_label, run=$run"
    echo "=========================================="

    mkdir -p "${output_dir}/run-${run}"

    if [[ "$lammps" == /* ]]; then
        lammps_cmd="$lammps"
    else
        lammps_cmd="./$lammps"
    fi

    # Create temp input file in input folder
    input_file="input/${opt_prefix}_vanilla_${config_label}_run${run}.in"
    cp "$INPUT_FILE" "$input_file"

    sed -i "s|^read_data[[:space:]]*.*|read_data       input/data.chain|" "$input_file"

    md_start_time=$(date "+%Y-%m-%dT%H:%M:%S")

    # Run LAMMPS with Kokkos (GPU-resident, multicore only)
    if [[ "$USE_GPU" == "1" ]]; then
        srun --export=ALL --exact --exclusive --cpu-bind=cores \
            -n 1 --cpus-per-task="$N_CORES" --distribution=block:block \
            "$lammps_cmd" -k on g 1 t "$N_CORES" -sf kk -pk kokkos newton on neigh half \
            -in "$input_file" -log "${output_dir}/run-${run}/${opt_prefix}.log" > "${output_dir}/run-${run}/${opt_prefix}.out" 2>&1 &
    else
        srun --export=ALL --exact --exclusive --cpu-bind=cores \
            -n 1 --cpus-per-task="$N_CORES" --distribution=block:block \
            "$lammps_cmd" -k on t "$N_CORES" -sf kk -pk kokkos newton on neigh half \
            -in "$input_file" -log "${output_dir}/run-${run}/${opt_prefix}.log" > "${output_dir}/run-${run}/${opt_prefix}.out" 2>&1 &
    fi

    wait

    md_end_time=$(date "+%Y-%m-%dT%H:%M:%S")

    # Write job info log
    echo "$COMMON_LOG" > "${output_dir}/run-${run}/$LOG_FILE"
    {
        echo "Type of Simulation: vanilla"
        echo "Type of Run: prod"
        echo "MD Started: $md_start_time"
        echo "MD Ended: $md_end_time"
    } >> "${output_dir}/run-${run}/$LOG_FILE"

    rm -f "$input_file"

done

echo "=========================================="
echo "Vanilla Kokkos optimization complete for config=$config_label"
echo "=========================================="
