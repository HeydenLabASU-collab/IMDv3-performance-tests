#!/bin/bash

input_folder="../../../../../GROMACS_INPUT"

mkdir -p performance
cd performance

for (( i=1; i<=5; i++ )); do
    run_folder="run${i}"
    mkdir -p "${run_folder}"
    
    # Prepare the simulation input
    gmx grompp -f ${input_folder}/step5_production_imdv3.mdp -o ${run_folder}/run.tpr -c ${input_folder}/step4.1_equilibration.gro -p ${input_folder}/topol.top -n ${input_folder}/index.ndx

    # Run the simulation
    gmx mdrun -v -deffnm ${run_folder}/run -ntmpi 1 -ntomp 24 -gpu_id 0 >& "${run_folder}_production.out"
done
