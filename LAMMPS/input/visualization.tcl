# ============================================================
# LAMMPS Polymer Chain Visualization Script
#
# Load files using (edit paths - VMD load option doesn't seem to work with lammpsdata file):
#   topo readlammpsdata "/path/to/data.chain" bond
#   mol addfile "/path/to/dump.lammpstrj" type lammpstrj waitfor all
# ============================================================

package require topotools
package require pbctools

# ---- Parameters for visualization ----
set keep_fraction 0.2    ;# fraction of chains to show (0.0 to 1.0)
set radius        21     ;# sphere radius to keep chains within (in Angstroms)
set focus_frag    99     ;# fragment index to highlight in foreground

# ---- Get unique fragments ----
set all [atomselect top "all"]
set frags [lsort -unique -integer [$all get fragment]]
$all delete

set m [molinfo top]

# ---- Pick a random frame if longer traj----
set nf [molinfo $m get numframes]
set rand_frame [expr {int(rand()*$nf)}]
animate goto $rand_frame
puts "Using frame: $rand_frame"

# ---- Filter: random sparse subset ----
# ---- Filter: keep only chains with COM within radius from origin for visualization ----
set keep {}
foreach f $frags {
    if {[expr {rand()}] >= $keep_fraction} { continue }

    set sel [atomselect $m "fragment $f"]
    set com [measure center $sel weight mass]
    $sel delete
    set x [lindex $com 0]
    set y [lindex $com 1]
    set z [lindex $com 2]
    if {[expr {$x*$x + $y*$y + $z*$z}] < $radius*$radius} {
        lappend keep $f
    }
}

# In case: keep at least one fragment
if {[llength $keep] == 0} { lappend keep [lindex $frags 0] }

puts "Showing [llength $keep] chains inside radius $radius"

# ---- Build reps ----
set nreps [molinfo top get numreps]
for {set i 0} {$i < $nreps} {incr i} { mol delrep 0 top }

# Rep 0: sparse background chains (Lines)
mol addrep top
mol modselect 0 top "fragment [join $keep { }]"
mol modstyle 0 top Lines 1.0
mol modcolor 0 top ColorID 1
mol modmaterial 0 top Transparent

# Rep 1: highlighted foreground chain (CPK balls and bonds)
mol addrep top
mol modselect 1 top "fragment $focus_frag"
mol modstyle 1 top CPK 1.2 0.5 24 24
mol modcolor 1 top ColorID 1
mol modmaterial 1 top Opaque

# ---- Display settings ----
axes location off
color Display Background white
display ambientocclusion on
display aoambient 0.8
display aodirect 0.4
display resetview

# ---- Render ----
# cd "/path/to/output/folder"
# render Tachyon newscene.dat
# GUI render command (paste in File > Render dialog):
# "C:\Program Files (x86)\University of Illinois\VMD\tachyon_WIN32.exe" -aasamples 12 -res 2100 2100 %s -format BMP -o "/path/to/output/polymer_image.bmp"
