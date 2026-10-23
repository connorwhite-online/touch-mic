// touch-mic — the form field, shared by form.scad and body.scad.
// No geometry is rendered here; include it and call blob().
//
// Needs BOSL2:  git clone https://github.com/BelfrySCAD/BOSL2 \
//                   ~/Documents/OpenSCAD/libraries/BOSL2

include <BOSL2/std.scad>
include <BOSL2/isosurface.scad>

// [x, y, z, r]. Pillowy and deliberately uneven: one dominant mass, lobes at
// different heights so the crown swells rather than domes, and a low broad
// lobe that spreads the base so the form reads as settled under its own
// weight. Radii vary a lot on purpose — equal lobes read as manufactured.
lobes = [
    [ -5.0,  -1.0, 4.6, 8.4],   // dominant mass, off-centre
    [  8.0,   4.0, 4.0, 6.6],
    [ -1.0, -10.0, 3.4, 5.8],
    [-11.0,   7.0, 3.8, 6.2],
    [ 13.0,  -6.0, 3.0, 5.0],   // small tip, breaks the symmetry
    [  3.0,   9.0, 4.4, 5.4],   // raised: reads as a pillow on the crown
    [ -3.0,  -2.0, 2.0, 8.8],   // the slump: low and broad
];

voxel    = 0.45;  // 0.35 for a final SLS order; 0.45 is fine for FDM
cutoff_k = 2.5;   // 3.0 melts the lobes into a sphere; 2.1 reads caterpillar
bbox     = [[-44, -40, -2], [44, 40, 38]];

module blob(iso = 1.0) {
    metaballs(
        spec = [
            for (l = lobes)
                each [move([l[0], l[1], l[2]]),
                      mb_sphere(l[3], cutoff = l[3] * cutoff_k)]
        ],
        bounding_box = bbox,
        voxel_size = voxel,
        isovalue = iso
    );
}
