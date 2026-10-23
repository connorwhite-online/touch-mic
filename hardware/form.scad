// touch-mic — form study
//
// Metaballs rather than hull(), because a convex hull of spheres genuinely has
// ruled surfaces and flat triangular patches between lobes. That faceting is
// real geometry, not a rendering artifact, and no amount of $fn removes it.
// Metaballs blend as a smooth scalar field, so the whole form is continuous.
//
// Needs BOSL2:  git clone https://github.com/BelfrySCAD/BOSL2 \
//                   ~/Documents/OpenSCAD/libraries/BOSL2
//
//   openscad -D 'part="form"' -o form.stl form.scad

include <BOSL2/std.scad>
include <BOSL2/isosurface.scad>

part = "form";   // "form" | "section"

/* [Form] */
// [x, y, z, r]. Pillowy and deliberately uneven: one dominant mass, lobes at
// different heights so the crown swells rather than domes, and a low broad
// lobe that spreads the base like the thing has settled under its own weight.
// Radii vary a lot on purpose — equal lobes read as manufactured, not gummy.
lobes = [
    [ -5.0,  -1.0, 4.6, 8.4],   // dominant mass, off-centre
    [  8.0,   4.0, 4.0, 6.6],
    [ -1.0, -10.0, 3.4, 5.8],
    [-11.0,   7.0, 3.8, 6.2],
    [ 13.0,  -6.0, 3.0, 5.0],   // small tip, breaks the symmetry
    [  3.0,   9.0, 4.4, 5.4],   // raised: reads as a pillow on the crown
    [ -3.0,  -2.0, 2.0, 8.8],   // the slump: low and broad
];

voxel    = 0.35;   // smaller = smoother surface, slower render
isovalue = 1.0;

// cutoff bounds each ball's influence. Without it, eleven balls summing with
// infinite reach push the field above the isovalue everywhere and the result
// is simply the bounding box, filled solid.
cutoff_k = 2.5;   // cutoff = cutoff_k * r. Larger = softer, fuller blending

module blob(iso = isovalue) {
    metaballs(
        spec = [
            for (l = lobes)
                each [move([l[0], l[1], l[2]]),
                      mb_sphere(l[3], cutoff = l[3] * cutoff_k)]
        ],
        bounding_box = [[-44, -40, -2], [44, 40, 38]],
        voxel_size = voxel,
        isovalue = iso
    );
}

// Flat bottom: everything below the ground plane removed.
module form() {
    difference() {
        blob();
        translate([0, 0, -200]) cube([400, 400, 400], center = true);
    }
}

if (part == "form") form();
else if (part == "section")
    difference() { form(); translate([-200, -200, -10]) cube([400, 200, 200]); }
else echo("set part to form or section");
