from imdclient.IMD import IMDReader
import MDAnalysis as mda
import logging

GMX_TOPOL = "/home/hcho96/imdv3-performance/GROMACS_INPUT/step3_input.pdb"

for run in range(1,6):

    logger = logging.getLogger(f"imdclient.IMDClient.{run}")

    if not logger.handlers:
    
        file_handler = logging.FileHandler("run"+str(run)+"/imdreader.log")
        formatter = logging.Formatter(
            "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
        )
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
        logger.setLevel(logging.DEBUG)

    i = 0
    u = mda.Universe(GMX_TOPOL, "imd://localhost:8888")
    for ts in u.trajectory:
        i += 1

    logger.info(f"Parsed {i} frames")
