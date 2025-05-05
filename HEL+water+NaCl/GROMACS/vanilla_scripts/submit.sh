#!/bin/bash
#SBATCH -p general
#SBATCH -G a100:1
#SBATCH -N 1
#SBATCH -c 12
#SBATCH -t 0-04:00                  # wall time (D-HH:MM)
#SBATCH -o GMX-perf-12C-auto.out
#SBATCH --job-name=vanilla-1G-12C
#SBATCH --exclusive

host=$(hostname)
echo "Running on node ${host}"

source '/home/hcho96/gromacs-2024.4/bin/GMXRC.bash'

# Equilibration and Minimization
#./equi.sh

# Vanilla code Production
./production.sh
