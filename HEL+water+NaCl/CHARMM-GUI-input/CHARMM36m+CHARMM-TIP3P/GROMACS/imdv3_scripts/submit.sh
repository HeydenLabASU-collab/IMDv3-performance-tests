#!/bin/bash
#SBATCH -p general
#SBATCH -G a100:1
#SBATCH -N 1
#SBATCH -c 24
#SBATCH -t 0-20:00                  # wall time (D-HH:MM)
#SBATCH -o GMX-perf-24C-imdv3.out
#SBATCH --job-name=imdv3-1G-24C-500
#SBATCH --exclusive

host=$(hostname)
echo "Running on node ${host}"

source "/home/hcho96/imd-v3/gromacs-imd-v3/bin/GMXRC.bash"
module load shpc/python/3.9.2-slim/module
module load mamba
source activate imdclient-new

# Equilibration and Minimization
#./equi.sh

# Production w/ no fileio
#./production.sh

# Production w/ fileio
#./production_fileio.sh

# Production w/ streaming on
./production_streaming.sh
