#!/usr/bin/env bash

# Parse NAMD output recursively under this engine's output directory.

awk_script="parser-NAMD.awk"
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
namd_out=""

for f in job_info_*.log; do
    if [ -f "$f" ]; then
        batch_log="$f"
        break
    fi
done

for f in step5_*.out; do
    if [ -f "$f" ]; then
        namd_out="$f"
        break
    fi
done

# Parse when at least one relevant file exists.
if [ -n "${namd_out}" ] || [ -n "${batch_log}" ]; then
    cat ${namd_out:+"${namd_out}"} ${batch_log:+"${batch_log}"} | awk -f "${awk_path}" >> "${output_dir}/${data_file}"
fi

# Recurse into subdirectories.
for d in */; do
    [ -d "${d}" ] || continue
    "${script_dir}/parser-NAMD.sh" "$(pwd)/${d%/}"
done