#!/usr/bin/env bash

input_folder="../../../../../GROMACS_INPUT"

freq_list=(1 5 8 50 500 5000 50000)
source '/scratch/hcho96/Research/imd-v3/gromacs-imd-v3/bin/GMXRC.bash'
module load mamba
source activate imdclient-new

for freq in "${freq_list[@]}"; do
    echo "Frequency: ${freq}"
    mkdir -p "frequency-${freq}"
    cd "frequency-${freq}"

    mkdir -p performance_streaming
    cd performance_streaming

    for (( i=1; i<=5; i++ )); do
        run_folder="run${i}"
        mkdir -p "${run_folder}"

        # Prepare the simulation input
        gmx grompp -f ${input_folder}/step5_production_imdv3_streaming_${freq}.mdp -o ${run_folder}/run.tpr -c ${input_folder}/step4.1_equilibration.gro -p ${input_folder}/topol.top -n ${input_folder}/index.ndx

        # Run the simulation
        gmx mdrun -v -deffnm ${run_folder}/run -ntmpi 1 -ntomp 24 -gpu_id 0 -imdwait -imdport 8888 >& "${run_folder}/production.out" &
        sleep 20
        python3 ${input_folder}/IMDv3-client.py "${run_folder}" &
        wait
    done

    cd ../../
done