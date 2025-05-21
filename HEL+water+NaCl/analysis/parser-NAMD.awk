BEGIN {
    data["SubmitDateTime"] = "N/A"
    data["StartDateTime"] = "N/A"
    data["EndDateTime"] = "N/A"
    data["ClusterName"] = "N/A"
    data["NodeNameList"] = "N/A"
    data["nGPUreq"] = "N/A"
    data["GPUtypereq"] = "N/A"
    data["nCPUreq"] = "N/A"
    data["CPUIDList"] = "N/A"
    data["SimType"] = "N/A"
    data["RunPurpose"] = "N/A"
    data["RunType"] = "N/A"
    data["nGPUused"] = "N/A"
    data["GPUtypeused"] = "N/A"
    data["GPUIDsused"] = "N/A"
    data["nCPUused"] = "N/A"
    data["CPUIDsused"] = "N/A"
    data["FileIOfreqLog"] = "N/A"
    data["FileIOfreqBox"] = "N/A"
    data["FileIOfreqPositions"] = "N/A"
    data["FileIOfreqVelocities"] = "N/A"
    data["FileIOfreqForces"] = "N/A"
    data["IMDfreqTime"] = "N/A"
    data["IMDfreqEnergies"] = "N/A"
    data["IMDfreqBox"] = "N/A"
    data["IMDfreqPositions"] = "N/A"
    data["IMDfreqVelocities"] = "N/A"
    data["IMDfreqForces"] = "N/A"
    data["PosWrap"] = "N/A"
    data["MDintstep"] = "N/A"
    data["nMDstep"] = "N/A"
    data["runTime"] = "N/A"
    data["performance"] = "N/A"
    data["stdevperformance"] = "N/A"
}

# data to be read from job_info.log (submission script output)
/Job Submitted/ {data["SubmitDateTime"] = $NF}
/Job Started/ {data["StartDateTime"] = $NF}
/Job Ended/ {data["EndDateTime"] = $NF}
/Cluster Name/ {data["ClusterName"] = $NF}
/Node Name List/ {data["NodeNameList"] = $NF}
/Requested number of GPUs/ {data["nGPUreq"] = $NF}
/Requested GPU Type/ {data["GPUtypereq"] = $NF}
/GPU IDs/ {data["GPUid"] = $NF}
/Requested number of CPUs/ {data["nCPUreq"] = $NF}
/CPU IDs/ {data["CPUIDList"] = $NF}
/Type of simulation/ {data["SimType"] = $NF}
/Purpose of the job/ {data["RunPurpose"] = $NF}

# data to be read from NAMD output file
/Info: Running on/ && /processors/ {data["nCPUused"] = $4}
/Info: TIMESTEP/ {data["MDintstep"] = $NF}
/Info: NUMBER OF STEPS/ {data["nMDstep"] = $NF}
/WallClock/ && /CPUTime/ {data["runTime"] = $4}
/PERFORMANCE/ && /averaging/ {data["performance"] = $4}

END {
    printf("%s, ",data["SubmitDateTime"])
    printf("%s, ",data["StartDateTime"])
    printf("%s, ",data["EndDateTime"])
    printf("%s, ",data["ClusterName"])
    printf("%s, ",data["NodeNameList"])
    printf("%s, ",data["nGPUreq"])
    printf("%s, ",data["GPUtypereq"])
    printf("%s, ",data["GPUid"])
    printf("%s, ",data["nCPUreq"])
    printf("%s, ",data["CPUIDList"])
    printf("%s, ",data["SimType"])
    printf("%s, ",data["RunType"])
    printf("%s, ",data["RunPurpose"])
    printf("%s, ",data["nGPUused"])
    printf("%s, ",data["nCPUused"])
    printf("%s, ",data["FileIOfreqLog"])
    printf("%s, ",data["FileIOfreqPositions"])
    printf("%s, ",data["FileIOfreqVelocities"])
    printf("%s, ",data["FileIOfreqForces"])
    printf("%s, ",data["FileIOfreqBox"])
    printf("%s, ",data["imdFreq"])
    printf("%s, ",data["MDintstep"])
    printf("%s, ",data["nMDstep"])
    printf("%s, ",data["runTime"])
    printf("%s, ",data["performance"])
    printf("\n")
}
