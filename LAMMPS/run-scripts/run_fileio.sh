#!/usr/bin/env bash

# LAMMPS file I/O production script.
# Usage: ./run_fileio_lammps.sh <n_threads> <gpu_device> <n_runs> <typeprod> <COMMON_LOG> <pos_freq> <vel_freq> <force_freq> <box_freq> <mode> <tasks> <workers> <exec_name> <use_gpu> <input_file> <sim_label>

# Input parameters
N_THREADS="${1:-2}"
GPU_DEVICE="${2:-0}"
N_RUNS="${3:-1}"
TYPEPROD="${4:-production}"
COMMON_LOG="${5:-}"
POS_FREQ="${6:-1}"       # Position output frequency
VEL_FREQ="${7:-0}"       # Velocity output frequency
FORCE_FREQ="${8:-0}"     # Force output frequency
BOX_FREQ="${9:-0}"       # Box output frequency
MODE="${10:-kokkos}"
TASKS="${11:-1}"
WORKERS="${12:-0}"
EXEC_NAME="${13:-bin/lmp_openmp_mpi_gpu_single_imdv3}"
USE_GPU="${14:-1}"
INPUT_FILE="${15:-input/in.chain-fileio}"
SIM_LABEL="${16:-fileio}" # fileio or fileio-3

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

# Calculate required cores
total_allocated=${#allocated[@]}
if [[ "$MODE" == "kokkos" ]]; then
    lammps_cores=$N_THREADS
    threads_per_task=$N_THREADS
    TASKS=0
    WORKERS=$N_THREADS
else
    echo "Error: Only kokkos mode is supported for fileio production."
    exit 1
fi
required=$lammps_cores

if (( total_allocated < required )); then
    echo "Warning: Not enough allocated cores. Allocated: $total_allocated, Required: $required"
fi

# Get core list
lammps_cores_array=("${allocated[@]:0:required}")
lammps_core_list=$(IFS=, ; echo "${lammps_cores_array[*]}")

# Variables for file paths
prod_prefix="step2_production_${SIM_LABEL}"
lammps="$EXEC_NAME"
if [[ "$MODE" == "kokkos" ]]; then
    config_label="${USE_GPU}-0-${N_THREADS}"
else
    echo "Error: Only kokkos mode is supported for fileio production."
    exit 1
fi
output_dir="output/${SIM_LABEL}/${TYPEPROD}/prod/${config_label}/frequency-${POS_FREQ}"
LOG_FILE="job_info_${SLURM_JOB_ID}.log"
export CHECK_CPU_LIST=1

mkdir -p "${output_dir}"

for run in $(seq 1 "$N_RUNS"); do
    echo "=========================================="
    echo "Running ${SIM_LABEL} production: config=$config_label, freq=$POS_FREQ, run=$run"
    echo "=========================================="

    mkdir -p "${output_dir}/run-${run}"

    if [[ "$lammps" == /* ]]; then
        lammps_cmd="$lammps"
    else
        lammps_cmd="./$lammps"
    fi

    # Create temp input file
    prod_run_input="input/${prod_prefix}_${config_label}_freq${POS_FREQ}_run${run}.in"
    cp "$INPUT_FILE" "$prod_run_input"

    # Fix read_data path
    sed -i "s|^read_data[[:space:]]*.*|read_data       input/data.chain|" "$prod_run_input"

    # Update output placeholders and frequencies.
    if grep -q "position_frequency" "$prod_run_input"; then
        sed -i "s/position_frequency/${POS_FREQ}/g" "$prod_run_input"
    fi
    if grep -q "velocity_frequency" "$prod_run_input"; then
        sed -i "s/velocity_frequency/${VEL_FREQ}/g" "$prod_run_input"
    fi
    if grep -q "force_frequency" "$prod_run_input"; then
        sed -i "s/force_frequency/${FORCE_FREQ}/g" "$prod_run_input"
    fi
    if grep -q "box_frequency" "$prod_run_input"; then
        sed -i "s/box_frequency/${BOX_FREQ}/g" "$prod_run_input"
    fi

    # Replace optional output filename tokens if present.
    if grep -q "pos_file" "$prod_run_input"; then
        sed -i "s/pos_file/${output_dir//\//\\/}\/run-${run}\/pos_file/g" "$prod_run_input"
    fi
    if grep -q "pos_vel_force_file" "$prod_run_input"; then
        sed -i "s/pos_vel_force_file/${output_dir//\//\\/}\/run-${run}\/pos_vel_force_file/g" "$prod_run_input"
    fi

    md_start_time=$(date "+%Y-%m-%dT%H:%M:%S")

    echo "Expected LAMMPS cores: ${lammps_core_list}"

    # Run LAMMPS with Kokkos + IMDv3
    if [[ "$MODE" == "kokkos" ]]; then
        if [[ "$USE_GPU" == "1" ]]; then
            srun --export=ALL --exact --exclusive --mpi=pmix --cpu-bind=cores \
                -n 1 --cpus-per-task="$threads_per_task" --distribution=block:block \
                bash -lc 'if [[ "${CHECK_CPU_LIST:-0}" == "1" ]]; then cpus=$(grep Cpus_allowed_list /proc/self/status | cut -f2); echo "[CPU-CHECK][LAMMPS] host=$(hostname) pid=$$ cpus=${cpus}"; fi; "$@"' bash \
                "$lammps_cmd" -k on g 1 t "$threads_per_task" -sf kk -pk kokkos newton on neigh half \
                -in "$prod_run_input" -log "${output_dir}/run-${run}/${prod_prefix}.log" > "${output_dir}/run-${run}/${prod_prefix}.out" 2>&1 &
        else
            srun --export=ALL --exact --exclusive --mpi=pmix --cpu-bind=cores \
                -n 1 --cpus-per-task="$threads_per_task" --distribution=block:block \
                bash -lc 'if [[ "${CHECK_CPU_LIST:-0}" == "1" ]]; then cpus=$(grep Cpus_allowed_list /proc/self/status | cut -f2); echo "[CPU-CHECK][LAMMPS] host=$(hostname) pid=$$ cpus=${cpus}"; fi; "$@"' bash \
                "$lammps_cmd" -k on t "$threads_per_task" -sf kk -pk kokkos newton on neigh half \
                -in "$prod_run_input" -log "${output_dir}/run-${run}/${prod_prefix}.log" > "${output_dir}/run-${run}/${prod_prefix}.out" 2>&1 &
        fi
    else
        echo "Error: Only kokkos mode is supported for fileio production."
        exit 1
    fi

    wait

    md_end_time=$(date "+%Y-%m-%dT%H:%M:%S")

    # Write job info log
    echo "$COMMON_LOG" > "${output_dir}/run-${run}/$LOG_FILE"
    {
        echo "Type of Simulation: ${SIM_LABEL}"
        echo "Type of Run: prod"
        echo "MD Started: $md_start_time"
        echo "MD Ended: $md_end_time"
    } >> "${output_dir}/run-${run}/$LOG_FILE"

    rm -f "$prod_run_input"
    echo ""
done

echo "=========================================="
echo "${SIM_LABEL} production complete for config=$config_label, freq=$POS_FREQ"
echo "=========================================="
