// touch-mic — body
//
// The metaball form from blob.scad, shelled, with the internals: a plunger
// hanging from the crown onto a tactile switch, a cradle for the XIAO, a
// USB-C aperture, a compliant waist, and a service slot in the floor.
//
// Shelling is done with two isovalues rather than an offset, because you
// cannot offset an implicit surface uniformly. Measured on this form:
//
//   iso 1.00  outer          top z 18.19   width 40.55
//   iso 1.25  crown 1.80mm   sides 1.02mm
//   iso 1.50  crown 2.73mm   sides 1.94mm   <- used
//
// The wall is deliberately not uniform: a broad crown has a gentler field
// gradient than a steep flank. That suits this design — a stiff crown
// transmits an edge press to the plunger instead of denting locally, while
// the thinner flank is where the waist flexure wants to be.
//
//   openscad -D 'part="body"'    -o body.stl    body.scad
//   openscad -D 'part="section"' -o section.stl body.scad

include <blob.scad>

part = "body";   // "body" | "section"

iso_outer = 1.00;
iso_inner = 1.50;

floor_t   = 2.2;    // closed flat bottom

/* [Press] */
switch_h  = 4.3;    // tactile switch actuator height above the floor
gap       = 0.8;    // pre-travel before the plunger touches the switch
plunger_d = 7;
plunger_x = 8;      // offset from centre: the board takes the other side
plunger_y = 0;

/* [Waist flexure] */
waist_z   = 3.0;
waist_h   = 4.5;
waist_iso = 1.28;   // thins the flank over the band; higher = thinner = softer

/* [Electronics] */
board_l   = 22.0;   // pocket, not part: XIAO SAMD21 is 21 x 17.8
board_w   = 19.0;
board_x   = -7;
retain_h  = 3.4;
usb_w     = 10.0;
usb_h     = 4.2;
usb_z     = floor_t + 1.9;

// ---------------------------------------------------------------- pieces

module cut_below(z) {
    translate([0, 0, z - 200]) cube([500, 500, 400], center = true);
}

module outer() { difference() { blob(iso_outer); cut_below(0); } }

// The void. Floor at floor_t, so the bottom is closed.
module cavity() { difference() { blob(iso_inner); cut_below(floor_t); } }

// Intersecting a tall column with the cavity makes the plunger meet the
// crown's inner surface exactly, whatever its local height — no need to know
// the crown height at this x,y, and it follows the form if the lobes move.
module plunger() {
    intersection() {
        cavity();
        translate([plunger_x, plunger_y, floor_t + switch_h + gap])
            cylinder(h = 40, d = plunger_d, $fn = 48);
    }
}

// Low walls locating the board on the floor, clipped to the cavity so they
// can never punch through the shell.
module board_cradle() {
    intersection() {
        cavity();
        translate([board_x, 0, floor_t])
            difference() {
                translate([0, 0, retain_h / 2])
                    cube([board_l + 3.6, board_w + 3.6, retain_h], center = true);
                translate([0, 0, retain_h / 2 + 0.6])
                    cube([board_l, board_w, retain_h], center = true);
            }
    }
}

module body() {
    difference() {
        union() {
            difference() { outer(); cavity(); }
            plunger();
            board_cradle();
        }

        // Compliant waist: thin the flank over a band by removing the sliver
        // between the inner wall and a slightly larger isosurface.
        intersection() {
            difference() { blob(waist_iso); blob(iso_inner); }
            translate([0, 0, waist_z]) cylinder(h = waist_h, r = 300, $fn = 8);
        }

        // USB-C aperture through the -x flank
        translate([-60, 0, usb_z])
            rotate([0, 90, 0])
                hull() {
                    translate([0,  (usb_w - usb_h) / 2, 0]) cylinder(h = 90, d = usb_h, $fn = 32);
                    translate([0, -(usb_w - usb_h) / 2, 0]) cylinder(h = 90, d = usb_h, $fn = 32);
                }

        // Service slot: stretch it open to drop the parts in. Also the powder
        // escape a closed cavity requires for SLS.
        translate([0, 0, -1])
            hull() {
                translate([ 9, 2, 0]) cylinder(h = floor_t + 2, d = 9, $fn = 32);
                translate([-9, 2, 0]) cylinder(h = floor_t + 2, d = 9, $fn = 32);
            }
        translate([2, -11, -1]) cylinder(h = floor_t + 2, d = 4.5, $fn = 24);
    }
}

// ---------------------------------------------------------------- render

if (part == "body") body();
else if (part == "section")
    difference() { body(); translate([-250, -250, -10]) cube([500, 250, 200]); }
else if (part == "plunger") plunger();
else echo("set part to body, section or plunger");
