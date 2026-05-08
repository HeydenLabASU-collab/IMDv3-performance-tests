#!/usr/bin/env bash

#SBATCH -p general
#SBATCH -G a100:1
#SBATCH -N 1
#SBATCH -c 6 #48
#SBATCH -t 0-00:30                  # wall time (D-HH:MM)
#SBATCH -o GMX-perf-24C-streaming-output.out
#SBATCH --job-name=vanilla-1G-24C-streaming-output
# #SBATCH --exclusive

host=$(hostname)
echo "Running on node ${host}"

# Equilibration and Minimization
#./equi.sh

# Vanilla code Production
# ./production_streaming.sh
# ./production_fileio.sh
# ./production_fileio_3.sh
# ./production_fileio_xtc.sh
# ./production_streaming_3.sh
./production_streaming_output.sh