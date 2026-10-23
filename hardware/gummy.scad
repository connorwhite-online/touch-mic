// touch-mic — body form, drawn rather than grown
//
// Two approaches were tried and discarded before this one:
//
//   metaballs           — emergent, not drawn. Reads as a mess of blended
//                         spheres rather than a designed object.
//   hull of 2D circles  — a convex hull is arcs joined by STRAIGHT TANGENTS,
//                         so adding circles adds facets. It came out a polygon.
//
// This builds the plan from a smooth radial function instead. r(theta) is a
// constant plus a few low-order harmonics, so the outline is continuous by
// construction — there is no facet to find at any resolution — while the
// harmonics give deliberate, tunable asymmetry.
//
// The section is then a straight flank with a circular roll-over at the top
// and a small radius at the base. One edge radius governs the whole form,
// which is what the eye reads as "designed" rather than "melted".
//
//   openscad -D 'part="form"' -o gummy.stl gummy.scad

part = "form";   // "form" | "plan" | "sectionX" | "sectionY"

/* [Plan silhouette] */
R0 = 19.5;       // mean radius

// [amplitude, phase deg] for the 1st, 2nd and 3rd harmonics.
//   1st — offsets the mass to one side (egg / teardrop)
//   2nd — ovalises it
//   3rd — the soft rounded-triangle quality that keeps it from reading generic
// Amplitudes stay small; past ~0.15 the outline starts to pinch.
harmonics = [
    [0.150,  12],
    [0.105,  48],
    [0.055, 104],
];

/* [Section] */
H      = 17.0;   // overall height
R_top  = 10.0;    // top roll-over. Large = pillowy, small = slab-like
R_bot  = 1.8;    // small base radius so it doesn't look die-cut
steps  = 140;    // loft resolution
pts    = 180;    // points around the plan

function rad(t) =
    R0 * (1
        + harmonics[0][0] * cos(t - harmonics[0][1])
        + harmonics[1][0] * cos(2 * (t - harmonics[1][1]))
        + harmonics[2][0] * cos(3 * (t - harmonics[2][1])));

module plan_profile() {
    polygon([for (i = [0 : pts - 1])
        let (t = i * 360 / pts)
            [rad(t) * cos(t), rad(t) * sin(t)]]);
}

// How far the outline is drawn in at height z: zero through the straight
// flank, circular at both ends.
function inset(z) =
      z < R_bot     ? R_bot - sqrt(max(0, R_bot * R_bot - (R_bot - z) * (R_bot - z)))
    : z > H - R_top ? R_top - sqrt(max(0, R_top * R_top - (z - (H - R_top)) * (z - (H - R_top))))
    : 0;

module slice_at(z) {
    translate([0, 0, z])
        linear_extrude(height = 0.002)
            offset(r = -inset(z))
                plan_profile();
}

module gummy() {
    for (i = [0 : steps - 1]) {
        z0 = H * i / steps;
        z1 = H * (i + 1) / steps;
        hull() { slice_at(z0); slice_at(z1); }
    }
}

if (part == "form") gummy();
else if (part == "plan") plan_profile();
else if (part == "sectionX")
    difference() { gummy(); translate([-200, -200, -10]) cube([400, 200, 200]); }
else if (part == "sectionY")
    difference() { gummy(); translate([-200, -200, -10]) cube([200, 400, 200]); }
else echo("set part to form, plan, sectionX or sectionY");
