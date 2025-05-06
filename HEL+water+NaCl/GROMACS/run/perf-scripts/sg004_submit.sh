#!/bin/bash
#SBATCH -p general
#SBATCH -G a100:1
#SBATCH -N 1
#SBATCH -c 12
#SBATCH -t 0-04:00                  # wall time (D-HH:MM)
#SBATCH -o GMX-perf-12C.out
#SBATCH --job-name=imdv3-1G-12C-sg004
#SBATCH -w sg004
#SBATCH --exclusive

host=$(hostname)
echo "Running on node ${host}"

source "/home/hcho96/imd-v3/gromacs-imd-v3/bin/GMXRC.bash"

# Equilibration and Minimization
#./equi.sh

# Vanilla code Production
./production.sh
