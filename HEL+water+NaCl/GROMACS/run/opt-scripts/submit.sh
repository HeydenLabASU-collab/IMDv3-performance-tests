#!/bin/bash
#SBATCH -p general
#SBATCH -N 1
#SBATCH -c 12
#SBATCH -t 0-02:00                  # wall time (D-HH:MM)
#SBATCH -o test.out

host=$(hostname)
echo "Running on node ${host}"

source '/home/hcho96/gromacs-2024.4/bin/GMXRC.bash'

# Equilibration and Minimization
./equi.sh

# Vanilla code Production
./prod_vanilla.sh
