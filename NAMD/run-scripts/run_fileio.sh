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
    if [[ -z "$SLURM_JOB_CPUS_LIST" ]]; then
        echo "SLURM_JOB_CPUS_LIST is not set."
        exit 1
    fi
    allocated=($(expand_cpu_list "$SLURM_JOB_CPUS_LIST"))
fi

# Input parameters
# Usage: ./script.sh <NAMD_CORES> <GPU_DEVICE> <n_runs> <typeprod> <COMMON_LOG> <pos_freq> <vel_freq> <force_freq> <box_freq> [MODE] [TASKS] [WORKERS] [EXEC_NAME] [USE_GPU] [INPUT_FILE] [SIM_LABEL]
NAMD_CORES="$1"    # Total cores (for multicore) or total reserved for NAMD (for mpi_smp)
GPU_DEVICE="$2"    # GPU device to use
n_runs="$3"        # Number of runs
typeprod="$4"      # Type of production (optimization/performance)
COMMON_LOG="$5"    # Common log information
pos_freq="$6"      # Frequency for position output
vel_freq="$7"      # Frequency for velocity output
force_freq="$8"    # Frequency for force output
box_freq="$9"      # Frequency for box output
MODE="${10:-multicore}"
TASKS="${11:-1}"
WORKERS="${12:-0}"
EXEC_NAME="${13:-bin/namd3_IMDv3_gpu_mc}"
USE_GPU="${14:-1}"
INPUT_FILE="${15:-input/step5_production_fileio.inp}"
SIM_LABEL="${16:-fileio}"  # folder label: fileio or fileio-3
PYTHON_CORES=0
CHECK_CPU_LIST=1

# Check if enough cores are allocated
total_allocated=${#allocated[@]}
if [[ "$MODE" == *"mpi_smp"* ]]; then
    required=$((TASKS * (WORKERS + 1) + PYTHON_CORES))
else
    required=$((NAMD_CORES + PYTHON_CORES))
fi
if (( total_allocated < required )); then
    echo "Not enough allocated cores. Allocated: $total_allocated, Required: $required"
    exit 1
fi

# Get NAMD core list
if [[ "$MODE" == *"mpi_smp"* ]]; then
    total_cores=$((TASKS * (WORKERS + 1)))
else
    total_cores="$NAMD_CORES"
    TASKS=0
    WORKERS=$NAMD_CORES
fi
namd_cores_array=("${allocated[@]:0:total_cores}")
namd_core_list=$(IFS=, ; echo "${namd_cores_array[*]}")

# File/dir naming for file I/O production.
equi_prefix="step4_equilibration"
prod_prefix="step5_fileio"
namd="$EXEC_NAME"
output_dir="output/${SIM_LABEL}/${typeprod}/prod/${USE_GPU}-${TASKS}-${WORKERS}/frequency-${pos_freq}"
equi_dir="output/vanilla/performance/equil/1-0-40/run-1"

LOG_FILE="job_info_${SLURM_JOB_ID}.log"

for run in $(seq 1 "$n_runs"); do
    # Create output directory for this run.
    if [[ ! -d "${output_dir}/run-${run}" ]]; then
        mkdir -p "${output_dir}/run-${run}"
    fi

    if [[ "$namd" == /* ]]; then
        namd_cmd="$namd"
    else
        namd_cmd="./$namd"
    fi

    prod_run_input="input/${prod_prefix}_${SIM_LABEL}_run_${run}.inp"
    sed "s|^outputName.*|outputName              ../${output_dir}/run-${run}/${prod_prefix};|" "$INPUT_FILE" > "$prod_run_input"
    sed -i "s|^set inputname.*|set inputname           ../${equi_dir}/${equi_prefix};|" "$prod_run_input"
    sed -i "s/position_frequency/${pos_freq}/g" "$prod_run_input"
    sed -i "s/velocity_frequency/${vel_freq}/g" "$prod_run_input"
    sed -i "s/force_frequency/${force_freq}/g" "$prod_run_input"
    # sed -i "s/box_frequency/${box_freq}/g" "$prod_run_input"

    md_start_time=$(date "+%Y-%m-%dT%H:%M:%S")

    # Run NAMD with srun and CPU-check logging.
    if [[ "$MODE" == *"mpi_smp"* ]]; then
        if [[ "$USE_GPU" == "1" ]]; then
            srun --export=ALL --exact --exclusive --mpi=pmix --cpu-bind=cores \
                -n "$TASKS" --cpus-per-task=$((WORKERS + 1)) --distribution=block:block \
                bash -lc 'if [[ "${CHECK_CPU_LIST:-0}" == "1" ]]; then cpus=$(grep Cpus_allowed_list /proc/self/status | cut -f2); echo "[CPU-CHECK][NAMD] host=$(hostname) pid=$$ cpus=${cpus}"; fi; "$@"' bash \
                "$namd_cmd" +ppn "$WORKERS" +setcpuaffinity +devices "$GPU_DEVICE" +ignoresharing \
                "$prod_run_input" > "${output_dir}/run-${run}/${prod_prefix}.out" 2>&1 &
        else
            srun --export=ALL --exact --exclusive --mpi=pmix --cpu-bind=cores \
                -n "$TASKS" --cpus-per-task=$((WORKERS + 1)) --distribution=block:block \
                bash -lc 'if [[ "${CHECK_CPU_LIST:-0}" == "1" ]]; then cpus=$(grep Cpus_allowed_list /proc/self/status | cut -f2); echo "[CPU-CHECK][NAMD] host=$(hostname) pid=$$ cpus=${cpus}"; fi; "$@"' bash \
                "$namd_cmd" +ppn "$WORKERS" +setcpuaffinity \
                "$prod_run_input" > "${output_dir}/run-${run}/${prod_prefix}.out" 2>&1 &
        fi
    else
        if [[ "$USE_GPU" == "1" ]]; then
            srun --export=ALL --exact --exclusive --cpu-bind=cores \
                -n 1 --cpus-per-task=$NAMD_CORES --distribution=block:block \
                bash -lc 'if [[ "${CHECK_CPU_LIST:-0}" == "1" ]]; then cpus=$(grep Cpus_allowed_list /proc/self/status | cut -f2); echo "[CPU-CHECK][NAMD] host=$(hostname) pid=$$ cpus=${cpus}"; fi; "$@"' bash \
                "$namd_cmd" +p"$NAMD_CORES" +setcpuaffinity +devices "$GPU_DEVICE" \
                "$prod_run_input" > "${output_dir}/run-${run}/${prod_prefix}.out" 2>&1 &
        else
            srun --export=ALL --exact --exclusive --cpu-bind=cores \
                -n 1 --cpus-per-task=$NAMD_CORES --distribution=block:block \
                bash -lc 'if [[ "${CHECK_CPU_LIST:-0}" == "1" ]]; then cpus=$(grep Cpus_allowed_list /proc/self/status | cut -f2); echo "[CPU-CHECK][NAMD] host=$(hostname) pid=$$ cpus=${cpus}"; fi; "$@"' bash \
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
        echo "Type of Simulation: ${SIM_LABEL}"
        echo "Type of Run: prod"
        echo "MD Started: $md_start_time"
        echo "MD Ended: $md_end_time"
    } >> "${output_dir}/run-${run}/$LOG_FILE"
done
