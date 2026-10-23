// touch-mic — the form, shared by gummy.scad (bare shape) and body.scad
// (shape plus internals). Nothing renders here.
//
// The plan is a smooth radial function: a constant plus three low-order
// harmonics. Continuous by construction, so there is no facet at any
// resolution, while the harmonics give deliberate, tunable asymmetry.
//
// The section is a straight flank with a circular roll-over at the top and a
// small radius at the base. One edge language governs the whole form.

/* [Plan silhouette] */
R0  = 19.5;      // mean radius
pts = 180;       // points around the plan

// [amplitude, phase deg] for the 1st, 2nd and 3rd harmonics.
//   1st — offsets the mass to one side (egg / teardrop)
//   2nd — ovalises it
//   3rd — the soft rounded-triangle quality that keeps it from reading generic
harmonics = [
    [0.150,  12],
    [0.105,  48],
    [0.055, 104],
];

/* [Section] */
H     = 17.0;    // overall height
R_top = 10.0;    // top roll-over. Large = pillowy, small = slab-like
R_bot = 1.8;     // small base radius so it doesn't look die-cut
steps = 140;     // loft resolution

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

// Inward draw of the outline at height z within a section of height h.
function ins(z, h, rt, rb) =
      z < rb     ? rb - sqrt(max(0, rb * rb - (rb - z) * (rb - z)))
    : z > h - rt ? rt - sqrt(max(0, rt * rt - (z - (h - rt)) * (z - (h - rt))))
    : 0;

// A lofted solid: the plan drawn in by `off` everywhere, swept from zb through
// height h with roll radii rt (top) and rb (base).
//
// Offsetting this whole solid inward by w is exact and trivial: shrink the
// plan by w, drop the height by w, and reduce the top radius by w. That is
// why the wall here is honest everywhere, unlike shelling an implicit surface
// where the wall drifts with the field gradient.
module solid(off = 0, zb = 0, h = H, rt = R_top, rb = R_bot, n = steps) {
    for (i = [0 : n - 1]) {
        z0 = h * i / n;
        z1 = h * (i + 1) / n;
        hull() {
            translate([0, 0, zb + z0]) linear_extrude(0.002)
                offset(r = -(off + ins(z0, h, rt, rb))) plan_profile();
            translate([0, 0, zb + z1]) linear_extrude(0.002)
                offset(r = -(off + ins(z1, h, rt, rb))) plan_profile();
        }
    }
}
