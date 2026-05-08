#!/usr/bin/env bash

# Parse LAMMPS output recursively under this engine's output directory.

awk_script="parser-LAMMPS.awk"
output_dir_name="output"
data_file="performance_data.csv"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
engine_dir="$(cd "${script_dir}/.." && pwd)"
output_dir="${engine_dir}/${output_dir_name}"
awk_path="${script_dir}/${awk_script}"

if [ ! -d "${output_dir}" ]; then
    echo "Error: ${output_dir} not found"
    exit 1
fi

if [ -z "$1" ]; then
    current_dir="${output_dir}"
else
    current_dir="$1"
fi

cd "${current_dir}" || exit 1

batch_log=""
lammps_out=""

for f in job_info*.log; do
    if [ -f "$f" ]; then
        batch_log="$f"
        break
    fi
done

for f in step*.out; do
    if [ -f "$f" ]; then
        lammps_out="$f"
        break
    fi
done

if [ -z "${lammps_out}" ]; then
    for f in step*.log; do
        if [ -f "$f" ]; then
            lammps_out="$f"
            break
        fi
    done
fi

# Parse only when both run output and job metadata are present.
if [ -n "${batch_log}" ] && [ -n "${lammps_out}" ]; then
    cat "${lammps_out}" "${batch_log}" | awk -v runDir="$PWD" -f "${awk_path}" >> "${output_dir}/${data_file}"
fi

# Recurse into subdirectories.
for d in */; do
    [ -d "${d}" ] || continue
    "${script_dir}/parser-LAMMPS.sh" "$(pwd)/${d%/}"
done