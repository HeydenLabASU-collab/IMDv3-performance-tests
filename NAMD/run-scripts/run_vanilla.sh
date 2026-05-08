#!/usr/bin/env bash

# Function to expand a CPU list (e.g., "1-2,20-21,42-45") into an array of individual cores
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

# Resolve allocated CPU IDs from thisjob or SLURM.
cpu_ids=$(thisjob | grep CPU_IDs | sed -E 's/.*CPU_IDs=([^ ]+).*/\1/')
if [[ -n "$cpu_ids" ]]; then
    echo "Using CPU_IDs from thisjob: $cpu_ids"
    allocated=($(expand_cpu_list "$cpu_ids"))
else
    # Fallback to SLURM list.
    if [[ -z "$SLURM_JOB_CPUS_LIST" ]]; then
        echo "SLURM_JOB_CPUS_LIST is not set."
        exit 1
    fi
    allocated=($(expand_cpu_list "$SLURM_JOB_CPUS_LIST"))
fi

# Input parameters
# Usage: ./script.sh <NAMD_CORES> <GPU_DEVICE> <n_runs> <typeprod> <COMMON_LOG> [MODE] [TASKS] [WORKERS] [EXEC_NAME] [USE_GPU]
NAMD_CORES="$1"
GPU_DEVICE="$2"
n_runs="$3"
typeprod="$4"
COMMON_LOG="$5"
MODE="${6:-multicore}"
TASKS="${7:-1}"
WORKERS="${8:-0}"
EXEC_NAME="${9:-bin/namd3_vanilla_gpu_mc}"
USE_GPU="${10:-1}"
INPUT_FILE="${11:-input/step5_production_vanilla.inp}"
PYTHON_CORES=0

# Check if enough cores are allocated
total_allocated=${#allocated[@]}
if [[ "$MODE" == *"mpi_smp"* ]]; then
    required=$((TASKS * (WORKERS + 1)))
else
    required=$((NAMD_CORES + PYTHON_CORES))
fi
if (( total_allocated < required )); then
    echo "Not enough allocated cores. Allocated: $total_allocated, Required: $required"
    exit 1
fi

# Build NAMD core list.
if [[ "$MODE" == *"mpi_smp"* ]]; then
    total_cores=$((TASKS * (WORKERS + 1)))
else
    total_cores="$NAMD_CORES"
    TASKS=0
    WORKERS=$NAMD_CORES
fi
namd_cores_array=("${allocated[@]:0:total_cores}")
namd_core_list=$(IFS=, ; echo "${namd_cores_array[*]}")

# File/dir naming.
equi_prefix="step4_equilibration"
prod_prefix="step5_opt_vanilla"
namd="$EXEC_NAME"
OUTPUT_DIR="output/vanilla/${typeprod}/prod"
equi_dir="output/vanilla/performance/equil/1-1-40/run-1"

LOG_FILE="job_info_${SLURM_JOB_ID}.log"

echo "Running production for $n_runs runs with NAMD core list: $namd_core_list and GPU device: $GPU_DEVICE"

if [[ "$WORKERS" -eq 0 ]]; then
    WORKERS="$NAMD_CORES"
fi

for run in $(seq 1 "$n_runs"); do
    # Create output directory
    output_dir="${OUTPUT_DIR}/${USE_GPU}-${TASKS}-${WORKERS}"
    mkdir -p "${output_dir}/run-${run}"

    # Create temporary input file in input/ so relative paths resolve
    prod_run_input="input/${prod_prefix}_run_${run}.inp"
    sed "s|^outputName.*|outputName              ../${output_dir}/run-${run}/${prod_prefix};|" "$INPUT_FILE" > "$prod_run_input"
    sed -i "s|^set inputname.*|set inputname           ../${equi_dir}/${equi_prefix};|" "$prod_run_input"

    # Resolve executable path.
    if [[ "$namd" == /* ]]; then
        namd_cmd="$namd"
    else
        namd_cmd="./$namd"
    fi

    md_start_time=$(date "+%Y-%m-%dT%H:%M:%S")

    # Run NAMD for the selected mode.
    if [[ "$MODE" == *"mpi_smp"* ]]; then
        if [[ "$USE_GPU" == "1" ]]; then
            srun --export=ALL --exact --exclusive --gres=gpu:a100:1 --mpi=pmix --cpu-bind=cores \
                -n "$TASKS" --cpus-per-task=$((WORKERS + 1)) --distribution=block:block \
                "$namd_cmd" +ppn "$WORKERS" +setcpuaffinity +devices "$GPU_DEVICE" +ignoresharing \
                "$prod_run_input" > "${output_dir}/run-${run}/${prod_prefix}.out" 2>&1 &
        else
            srun --export=ALL --exact --exclusive --mpi=pmix --cpu-bind=cores \
                -n "$TASKS" --cpus-per-task=$((WORKERS + 1)) --distribution=block:block \
                "$namd_cmd" +ppn "$WORKERS" +setcpuaffinity \
                "$prod_run_input" > "${output_dir}/run-${run}/${prod_prefix}.out" 2>&1 &
        fi
    else
        if [[ "$USE_GPU" == "1" ]]; then
            srun --export=ALL --exact --exclusive --gres=gpu:a100:1 --cpu-bind=cores \
                -n 1 --cpus-per-task=$NAMD_CORES --distribution=block:block \
                "$namd_cmd" +p"$NAMD_CORES" +setcpuaffinity +devices "$GPU_DEVICE" \
                "$prod_run_input" > "${output_dir}/run-${run}/${prod_prefix}.out" 2>&1 &
        else
            srun --export=ALL --exact --exclusive --cpu-bind=cores \
                -n 1 --cpus-per-task=$NAMD_CORES --distribution=block:block \
                "$namd_cmd" +p"$NAMD_CORES" +setcpuaffinity \
                "$prod_run_input" > "${output_dir}/run-${run}/${prod_prefix}.out" 2>&1 &
        fi
    fi
    wait

    md_end_time=$(date "+%Y-%m-%dT%H:%M:%S")

    rm -f "$prod_run_input"

    # Write job info log
    echo "$COMMON_LOG" > "${output_dir}/run-${run}/$LOG_FILE"
    {
        echo "Type of Simulation: vanilla"
        echo "Type of Run: prod"
        echo "MD Started: $md_start_time"
        echo "MD Ended: $md_end_time"
    } >> "${output_dir}/run-${run}/$LOG_FILE"
done
