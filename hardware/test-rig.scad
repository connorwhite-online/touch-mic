// touch-mic — capacitive test rig
//
// Answers the three questions that decide whether this device works at all:
//   1. How thin must the touch wall be for a usable signal?
//   2. How big does the electrode need to be?
//   3. How far from the electrode can you touch and still register?
//
// Print the coupons in TPU (the body material) and the pucks in conductive PLA
// (the electrode material). Print AS MODELLED — the touch surface is the face
// on the build plate, so it comes out smooth, and every pocket opens upward and
// needs no supports.
//
// Wire one puck to pin A0 on the XIAO, drop it in a pocket, run firmware/code.py
// and watch the serial numbers. Move it from station to station.
//
// Render one part at a time:
//   openscad -D 'part="ladder"' -o ladder.stl test-rig.scad
//   openscad -D 'part="puck"'   -o puck.stl   test-rig.scad
//   openscad -D 'part="reach"'  -o reach.stl  test-rig.scad

part = "ladder";   // "ladder" | "puck" | "reach"

/* [Wall thickness ladder] */
// 0.8 is deliberately below the 1.0 mm SLS TPU minimum — it shows where the
// PROCESS fails, which is a different limit from where SENSING fails.
thicknesses = [0.8, 1.0, 1.2, 1.5, 2.0, 3.0];

/* [Electrode] */
puck_dia   = 14;    // change this and reprint to test electrode size
puck_h     = 2;
pocket_fit = 0.35;  // clearance; TPU grips, so this is generous

/* [Geometry] */
station_w = 22;
station_d = 26;
pocket_h  = 4;      // headroom above the puck for the wire
label_h   = 0.6;

/* [Reach test] */
reach_wall = 1.2;   // set this to whatever the ladder says is your best wall
reach_len  = 80;
reach_w    = 20;

// ---------------------------------------------------------------- helpers

// max() over a vector isn't portable across OpenSCAD versions.
function vmax(v, i = 0, m = 0) = i >= len(v) ? m : vmax(v, i + 1, max(m, v[i]));

max_t = vmax(thicknesses);
H     = max_t + pocket_h;
pock  = puck_dia + pocket_fit * 2;

module pocket_at(x, floor_z) {
    translate([x, station_d / 2, floor_z])
        cylinder(h = H - floor_z + 1, d = pock, $fn = 72);
}

module label(x, y, z, s, size = 4) {
    translate([x, y, z])
        linear_extrude(label_h)
            text(s, size = size, halign = "center", valign = "center");
}

// ---------------------------------------------------------------- parts

// Six stations, one per wall thickness. Same outer height throughout, so the
// pocket simply gets deeper as the wall gets thinner.
module ladder() {
    n = len(thicknesses);
    L = n * station_w;

    difference() {
        cube([L, station_d, H]);
        for (i = [0 : n - 1])
            pocket_at(i * station_w + station_w / 2, thicknesses[i]);
    }

    // Raised labels on the top face, clear of the pockets.
    for (i = [0 : n - 1])
        label(i * station_w + station_w / 2, 4.2, H, str(thicknesses[i]), 5.5);
}

// The electrode. Print in conductive PLA.
// The slot lets a stripped wire end lie flat and get trapped by the puck
// sitting down in its pocket — no solder to the puck, nothing to come loose.
module puck() {
    difference() {
        cylinder(h = puck_h, d = puck_dia, $fn = 72);
        translate([-0.75, -(puck_dia / 2 + 1), puck_h - 0.9])
            cube([1.5, puck_dia + 2, 1.2]);
    }
}

// One station with a long thin tongue running off it. Put the puck in the
// station, then touch along the tongue at each mark and watch delta decay.
// This is the "can you really touch anywhere?" question, measured.
module reach() {
    difference() {
        union() {
            cube([station_w, station_d, H]);
            translate([station_w, (station_d - reach_w) / 2, 0])
                cube([reach_len, reach_w, reach_wall]);
        }
        pocket_at(station_w / 2, reach_wall);
    }

    for (x = [10 : 10 : reach_len - 10])
        label(station_w + x, station_d / 2, reach_wall, str(x), 3);
}

// ---------------------------------------------------------------- render

if      (part == "ladder") ladder();
else if (part == "puck")   puck();
else if (part == "reach")  reach();
else                       echo("set part to ladder, puck or reach");
