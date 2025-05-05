#!/bin/bash

input_folder="../../../../../GROMACS_INPUT"

mkdir -p performance_streaming
cd performance_streaming

for (( i=1; i<=5; i++ )); do
    run_folder="run${i}"
    mkdir -p "${run_folder}"
    
    # Prepare the simulation input
    gmx grompp -f ${input_folder}/step5_production_imdv3_streaming_500.mdp -o ${run_folder}/run.tpr -c ${input_folder}/step4.1_equilibration.gro -p ${input_folder}/topol.top -n ${input_folder}/index.ndx

    # Run the simulation
    gmx mdrun -v -deffnm ${run_folder}/run -ntmpi 1 -ntomp 20 -gpu_id 0 -imdwait -imdport 8888  >& "${run_folder}_production.out" &
    sleep 2
    python3 ${input_folder}/IMDv3-client.py
done
