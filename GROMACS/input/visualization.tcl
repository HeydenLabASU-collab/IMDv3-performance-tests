# ============================================================
# GROMACS HEWL + Water + NaCl Visualization Script
#
# Load your files first:
#   mol new "/path/to/step4.1_equilibration.gro"
# ============================================================

# ---- Remove old existing reps if any ----
set nreps [molinfo top get numreps]
for {set i 0} {$i < $nreps} {incr i} { mol delrep 0 top }

# ---- Compute protein center of mass ----
set protsel [atomselect top "protein"]
set com [measure center $protsel weight mass]
set cx [lindex $com 0]
set cy [lindex $com 1]
set cz [lindex $com 2]
$protsel delete

# ---- sphere centered at protein COM for visualization ----
set sphere "sqr(x - $cx) + sqr(y - $cy) + sqr(z - $cz) < sqr(20)"

# ---- Rep 0: Protein - colored by secondary structure ----
mol addrep top
mol modselect 0 top "protein and ($sphere)"
mol modstyle 0 top NewCartoon
mol modcolor 0 top Structure

# ---- Rep 1: Ions within sphere radius ----
mol addrep top
mol modselect 1 top "resname SOD CLA and ($sphere)"
mol modstyle 1 top VDW 0.3 12
mol modcolor 1 top Name

# ---- Rep 2: Water shell between 5.5 and 6A shell ----
mol addrep top
mol modselect 2 top "(same residue as (resname TIP3 and within 6 of protein)) and not (same residue as (resname TIP3 and within 5.5 of protein)) and ($sphere)"
mol modstyle 2 top VDW 0.3 12
mol modcolor 2 top Name

# ---- Rep 3: Water shell - O-H bonds only (no H-H artificial ones) ----
mol addrep top
mol modselect 3 top "(same residue as (resname TIP3 and within 6 of protein)) and not (same residue as (resname TIP3 and within 5.5 of protein)) and ($sphere)"
mol modstyle 3 top DynamicBonds 1.2 0.1 12
mol modcolor 3 top Name

# ---- Display settings ----
axes location off
color Display Background white
display ambientocclusion on
display aoambient 0.8
display aodirect 0.4
display resetview

# ---- Render ----
# cd "/path/to/output/folder"
# render Tachyon scene.dat
# GUI render command (paste into File > Render dialog):
# "C:\Program Files (x86)\University of Illinois\VMD\tachyon_WIN32.exe" -aasamples 12 -res 2100 2100 %s -format BMP -o "/path/to/output/hel_image.bmp"
