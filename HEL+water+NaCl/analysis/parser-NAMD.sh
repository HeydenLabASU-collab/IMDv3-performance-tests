#!/bin/bash

awk=parser-NAMD.awk
MDengine=NAMD
outputDir=output

# if this is the first (parent) execution
# save pwd and script name
# then pass it down to child executions
# in sub-directories
if [ -z $1 ]; then
startDir=$(pwd)
script=$0
# cd into the MDengine/output sub-directory
cd ${startDir}/${MDengine}/${outputDir} || {
    echo "Error: ${MDengine}/${outputDir} not found"
    exit 1
}
else
startDir=$1
script=$2
fi

scriptDir=$(dirname ${script})

# does current directory contain any recognized files
if [ -f job_info.log ] || [ -f *.out ]; then
# is a batch script output file present?
if [ -f job_info.log ]; then
batchLog=job_info.log
fi
# is a NAMD output file present?
if [ -f *.out ]; then
NAMDout=$(ls *.out)
fi
# concatenate and process with awk
cat ${NAMDout} ${batchLog} | awk -f ${startDir}/${scriptDir}/${awk}
fi

dir=( $(ls -rtlh | awk '/^d/ {print $9}') )
for d in ${dir[@]}
do
cd $d
${startDir}/${script} ${startDir} ${script}
cd ..
done
