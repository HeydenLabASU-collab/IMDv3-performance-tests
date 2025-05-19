BEGIN {
    data["submit"] = "N/A"
    data["start"] = "N/A"
    data["end"] = "N/A"
    data["cluster"] = "N/A"
    data["nodeList"] = "N/A"
    data["nGPUreq"] = "N/A"
    data["GPUtype"] = "N/A"
    data["GPUid"] = "N/A"
    data["nCPUreq"] = "N/A"
    data["CPUlist"] = "N/A"
    data["MDtype"] = "N/A"
    data["runType"] = "N/A"
    data["purpose"] = "N/A"
    data["nGPUused"] = "N/A"
    data["nCPUused"] = "N/A"
    data["fileIOfreqLog"] = "N/A"
    data["fileIOfreqPos"] = "N/A"
    data["fileIOfreqVel"] = "N/A"
    data["fileIOfreqFor"] = "N/A"
    data["fileIOfreqBox"] = "N/A"
    data["imdFreq"] = "N/A"
    data["MDstep"] = "N/A"
    data["nMDstep"] = "N/A"
    data["runTime"] = "N/A"
    data["performance"] = "N/A"
}

# data to be read from job_info.log (submission script output)
/Job Submitted/ {data["submit"] = $NF}
/Job Started/ {data["start"] = $NF}
/Job Ended/ {data["end"] = $NF}
/Cluster Name/ {data["cluster"] = $NF}
/Node Name List/ {data["nodeList"] = $NF}
/Requested number of GPUs/ {data["nGPUreq"] = $NF}
/Requested GPU Type/ {data["GPUtype"] = $NF}
/GPU IDs/ {data["GPUid"] = $NF}
/Requested number of CPUs/ {data["nCPUreq"] = $NF}
/CPU IDs/ {data["CPUlist"] = $NF}
/Purpose of the job/ {data["purpose"] = $NF}

# data to be read from NAMD output file
/Info: Running on/ && /processors/ {data["nCPUused"] = $4}
/Info: TIMESTEP/ {data["MDstep"] = $NF}
/Info: NUMBER OF STEPS/ {data["nMDstep"] = $NF}
/WallClock/ && /CPUTime/ {data["runTime"] = $4}
/PERFORMANCE/ && /averaging/ {data["performance"] = $4}

END {
    printf("%s, ",data["submit"])
    printf("%s, ",data["start"])
    printf("%s, ",data["end"])
    printf("%s, ",data["cluster"])
    printf("%s, ",data["nodeList"])
    printf("%s, ",data["nGPUreq"])
    printf("%s, ",data["GPUtype"])
    printf("%s, ",data["GPUid"])
    printf("%s, ",data["nCPUreq"])
    printf("%s, ",data["CPUlist"])
    printf("%s, ",data["MDtype"])
    printf("%s, ",data["runType"])
    printf("%s, ",data["purpose"])
    printf("%s, ",data["nGPUused"])
    printf("%s, ",data["nCPUused"])
    printf("%s, ",data["fileIOfreqLog"])
    printf("%s, ",data["fileIOfreqPos"])
    printf("%s, ",data["fileIOfreqVel"])
    printf("%s, ",data["fileIOfreqFor"])
    printf("%s, ",data["fileIOfreqBox"])
    printf("%s, ",data["imdFreq"])
    printf("%s, ",data["MDstep"])
    printf("%s, ",data["nMDstep"])
    printf("%s, ",data["runTime"])
    printf("%s, ",data["performance"])
    printf("\n")
}
