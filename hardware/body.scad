// touch-mic — body, low-profile pass
//
// An asymmetric organic pebble with a flat bottom. One piece, SLS TPU.
// Roughly 80 mm across and 13.5 mm tall — a stone on the desk, not a dome.
//
// Shelling note: the hull of a set of spheres is the Minkowski sum of a sphere
// with the convex hull of its centres. So shrinking every radius by the wall
// thickness, centres unmoved, is an EXACT uniform inward offset. A naive
// scaled-down copy would drift thick at the lobes; this does not.
//
// The low profile is what forces the layout: the switch and the board sit side
// by side on the floor rather than stacked, because the whole interior is only
// about 9 mm tall.
//
//   openscad -D 'part="body"'    -o body.stl    body.scad
//   openscad -D 'part="section"' -o section.stl body.scad

part = "body";   // "body" | "section" | "plan"

/* [Form] */
// [x, y, z, r]. Low centres and modest radii keep the crown near-flat; the
// asymmetry lives in plan, not elevation.
lobes = [
    [  0,   0, 3.0, 10.8],
    [ 15,  -4, 3.0, 10.4],
    [ 27,   3, 2.9,  9.6],
    [ 36,  -2, 2.8,  8.8],
    [-14,   5, 3.0, 10.4],
    [-26,  -3, 2.9,  9.8],
    [-34,   4, 2.8,  8.6],
    [  5,  13, 2.9,  9.6],
    [ -6, -13, 3.0, 10.0],
    [ 17,   9, 2.9,  9.2],
    [-18, -10, 2.9,  9.4],
];

wall     = 2.0;    // SLS TPU floor is 1.0; 2.0 gives the crown some stiffness
floor_t  = 2.2;    // closed flat bottom

/* [Press] */
// A band of reduced wall low on the body is the flexure: press anywhere on the
// crown and the shell settles onto the switch.
waist_z  = 3.2;
waist_h  = 4.0;
waist_w  = 1.0;    // the softness dial — thinner is a lighter press
plunger_d = 7;
switch_h = 4.3;    // tactile switch, actuator above the floor it sits on
gap      = 0.8;    // pre-travel before the switch is touched

/* [Electronics] */
board_l  = 22.0;   // pocket, not part: XIAO SAMD21 is 21 x 17.8
board_w  = 19.0;
board_x  = -22;    // off to one side; the cable exits -x
usb_w    = 10.0;
usb_h    = 4.2;
usb_z    = floor_t + 1.9;
retain_h = 3.2;    // low walls that locate the board without stacking height

$fn = 72;

// ---------------------------------------------------------------- form

module lobe_hull(shrink = 0) {
    hull()
        for (l = lobes)
            translate([l[0], l[1], l[2]])
                sphere(r = max(0.1, l[3] - shrink));
}

// Outer form: everything below the ground plane removed.
module outer() {
    difference() {
        lobe_hull(0);
        translate([0, 0, -200]) cube([500, 500, 400], center = true);
    }
}

// Inner cavity: floor sits at floor_t, so the bottom is closed.
module cavity() {
    difference() {
        lobe_hull(wall);
        translate([0, 0, floor_t - 200]) cube([500, 500, 400], center = true);
    }
}

function crown_z() = lobes[0][2] + lobes[0][3];

module plunger() {
    bot = floor_t + switch_h + gap;
    translate([0, 0, bot])
        cylinder(h = crown_z() - wall - bot + 0.01, d = plunger_d);
}

// Low retaining walls locating the board on the floor. Clipped to the cavity
// so they can never punch through the shell when a lobe moves.
module board_retainer() {
    intersection() {
        cavity();
        translate([board_x, 0, floor_t])
            difference() {
                translate([0, 0, retain_h / 2])
                    cube([board_l + 3.6, board_w + 3.6, retain_h], center = true);
                translate([0, 0, retain_h / 2])
                    cube([board_l, board_w, retain_h + 1], center = true);
            }
    }
}

module body() {
    difference() {
        union() {
            difference() { outer(); cavity(); }
            plunger();
            board_retainer();
        }
        // Compliant waist: remove a sliver from inside the wall over a band.
        intersection() {
            difference() { lobe_hull(waist_w); lobe_hull(wall); }
            translate([0, 0, waist_z]) cylinder(h = waist_h, r = 300);
        }
        // USB-C aperture through the -x wall
        translate([board_x - 60, 0, usb_z])
            rotate([0, 90, 0])
                hull() {
                    translate([0,  (usb_w - usb_h) / 2, 0]) cylinder(h = 90, d = usb_h);
                    translate([0, -(usb_w - usb_h) / 2, 0]) cylinder(h = 90, d = usb_h);
                }
        // Service slot in the floor: stretch it open to drop the parts in.
        // Doubles as the powder escape, which a closed cavity requires.
        translate([0, 0, -1])
            hull() {
                translate([ 12, 0, 0]) cylinder(h = floor_t + 2, d = 9);
                translate([-12, 0, 0]) cylinder(h = floor_t + 2, d = 9);
            }
        translate([24, -8, -1]) cylinder(h = floor_t + 2, d = 4.5);
    }
}

// ---------------------------------------------------------------- render

if (part == "body") body();
else if (part == "section")
    difference() { body(); translate([-250, -250, -10]) cube([500, 250, 200]); }
else if (part == "plan")
    projection(cut = false) body();
else echo("set part to body, section or plan");
