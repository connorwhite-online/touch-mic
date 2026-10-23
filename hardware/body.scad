// touch-mic — body with internals
//
// One piece. Outer form from profile.scad; the cavity is the same form with
// the plan drawn in by `wall`, the height dropped by `wall` and the top radius
// reduced by `wall` — an EXACT uniform offset.
//
// THE UNDERSIDE IS OPEN. It sits on a desk, so there is nothing to protect,
// and a closed floor made the thing unassemblable: a 21 mm board cannot pass
// through a service slot. The open base is also the powder escape SLS needs.
//
// Everything mounts on shelves that hang off the inner wall BELOW the waist.
// That matters: anything above the waist travels with the crown, so a switch
// mounted there would move with the plunger instead of being pressed by it.
//
// Parts press in from below. TPU flexes past the retention lips and springs
// back, so there are no screws and no glue.
//
//   openscad -D 'part="body"'    -o body.stl    body.scad
//   openscad -D 'part="lidoff"'  -o lidoff.stl  body.scad
//   openscad -D 'part="section"' -o section.stl body.scad

include <profile.scad>

part = "body";

wall    = 2.0;
rim_w   = 3.6;    // perimeter rim around the open underside
floor_t = 2.2;    // rim thickness
shelf_t = 1.4;    // mounting shelves, hung off the inner wall
bridge_w = 9.0;   // bar across the open underside, carries the switch load
base_z  = floor_t + shelf_t;   // everything mounts from here up

/* [XIAO SAMD21] */
board_l = 21.0;
board_w = 17.8;
board_t = 1.2;
conn_h  = 3.2;    // USB-C connector above the PCB
fit     = 0.5;    // clearance per side
rail_h  = 3.4;
rail_w  = 1.8;
lip_d   = 1.5;    // retention lip the PCB snaps past
board_y = -5.0;

/* [Switch] */
sw        = 6.0;
sw_seat_w = 1.2;
sw_seat_h = 1.6;
sw_body_h = 3.5;
sw_act_h  = 0.8;
sw_x      = 9.0;
sw_y      = 10.0;

/* [Press] */
plunger_d = 7.0;
gap       = 0.8;

/* [Waist flexure] */
waist_z    = 4.0;   // above the shelves, below the crown
waist_h    = 4.0;
waist_wall = 1.0;

// ---------------------------------------------------------------- derived

bridge_y = 10.0;   // runs under the switch

usb_dir  = 180;
usb_r    = rad(usb_dir);
usb_z    = base_z + board_t + conn_h / 2;
usb_w    = 9.6;
usb_t    = 3.6;
sw_top   = floor_t + sw_body_h + sw_act_h;
board_x0 = -(usb_r - wall - 0.5);
board_cx = board_x0 + board_l / 2;

module cavity(off = wall) {
    solid(off, floor_t, H - off - floor_t, R_top - off, 0.1);
}

// A bridge spanning the open underside, rim to rim. This is the load path:
// the plunger pushes DOWN on the switch, so the switch needs backing, and
// with no floor the only way to get it is a bar anchored at both ends.
// Oversized in x so it runs past the wall on both sides and joins the shell.
module bridge() {
    intersection() {
        difference() { solid(); cavity(); union() {} }
        translate([-60, bridge_y - bridge_w / 2, 0])
            cube([120, bridge_w, floor_t]);
    }
    intersection() {
        translate([0, 0, 0]) linear_extrude(height = floor_t) plan_profile();
        translate([-60, bridge_y - bridge_w / 2, 0])
            cube([120, bridge_w, floor_t]);
    }
}

// A shelf hung off the inner wall. Oversize it toward a wall or the bridge so
// it joins something; floating it in the middle leaves it unsupported.
module shelf(cx, cy, sx, sy) {
    intersection() {
        cavity();
        translate([cx - sx / 2, cy - sy / 2, floor_t])
            cube([sx, sy, shelf_t]);
    }
}

// ---------------------------------------------------------------- mounts

module board_bay() {
    bx = board_l + 2 * fit + 2 * rail_w;
    by = board_w + 2 * fit + 2 * rail_w;
    shelf(board_cx, board_y, bx, by);
    intersection() {
        cavity();
        union() {
            // three walls; the -x end stays open for the connector
            translate([board_cx - bx / 2, board_y - by / 2, base_z])
                difference() {
                    cube([bx, by, rail_h]);
                    translate([rail_w, rail_w, -1])
                        cube([board_l + 2 * fit, board_w + 2 * fit, rail_h + 2]);
                    translate([-1, rail_w, -1])
                        cube([rail_w + 1, board_w + 2 * fit, rail_h + 2]);
                }
            // retention lips: the PCB presses up past these and is held
            for (sy = [-1, 1])
                translate([board_cx,
                           board_y + sy * (board_w / 2 + fit),
                           base_z + board_t + lip_d / 2 + 0.1])
                    rotate([0, 90, 0])
                        cylinder(h = board_l * 0.6, d = lip_d, center = true, $fn = 16);
        }
    }
}

// Three walls on the bridge, open toward -y so the switch slides in from the
// access aperture rather than needing to pass through a floor.
module switch_seat() {
    ss = sw + 2 * sw_seat_w;
    intersection() {
        cavity();
        translate([sw_x, sw_y, floor_t])
            difference() {
                translate([-ss / 2, -ss / 2, 0]) cube([ss, ss, sw_body_h + 0.6]);
                translate([-(sw / 2 + 0.25), -(sw / 2 + 0.25), -1])
                    cube([sw + 0.5, sw + 0.5, sw_body_h + 2.6]);
                translate([-(sw / 2 - 0.6), -ss, -1])
                    cube([sw - 1.2, ss, sw_body_h + 2.6]);
            }
    }
}

module plunger() {
    intersection() {
        cavity();
        translate([sw_x, sw_y, sw_top + gap])
            cylinder(h = 40, d = plunger_d, $fn = 48);
    }
}

// ---------------------------------------------------------------- body

module body() {
    difference() {
        union() {
            difference() { solid(); cavity(); }
            bridge();
            board_bay();
            switch_seat();
            plunger();
        }
        // open underside, leaving the perimeter rim
        translate([0, 0, -1])
            linear_extrude(height = floor_t + 1)
                offset(r = -rim_w) plan_profile();

        // compliant waist
        intersection() {
            difference() { cavity(waist_wall); cavity(wall); }
            translate([0, 0, waist_z]) cylinder(h = waist_h, r = 300, $fn = 8);
        }

        // USB-C aperture. Starts 1.5 outside the flank and runs wall+6, so it
        // stops inside the cavity. A long cut from far away punches through
        // and leaves a second slot on the opposite flank.
        translate([-(usb_r + 1.5), board_y, usb_z])
            rotate([0, 90, 0])
                hull() {
                    translate([0,  (usb_w - usb_t) / 2, 0])
                        cylinder(h = wall + 6, d = usb_t, $fn = 32);
                    translate([0, -(usb_w - usb_t) / 2, 0])
                        cylinder(h = wall + 6, d = usb_t, $fn = 32);
                }
    }
}

module dummy_board() {
    translate([board_cx - board_l / 2, board_y - board_w / 2, base_z])
        cube([board_l, board_w, board_t]);
    translate([board_cx - board_l / 2 - 1.2, board_y - 4.4, base_z + board_t])
        cube([3.0, 8.8, conn_h]);
}

module dummy_switch() {
    translate([sw_x - sw / 2, sw_y - sw / 2, floor_t])
        cube([sw, sw, sw_body_h]);
    translate([sw_x, sw_y, floor_t + sw_body_h])
        cylinder(h = sw_act_h, d = 3.5, $fn = 24);
}

if (part == "body") body();
else if (part == "lidoff")
    difference() { body(); translate([-200, -200, 8.6]) cube([400, 400, 200]); }
else if (part == "section")
    difference() { body(); translate([-200, -200, -10]) cube([400, 200, 200]); }
else if (part == "dummy_board") dummy_board();
else if (part == "dummy_switch") dummy_switch();
else echo("set part to body, lidoff, section, dummy_board or dummy_switch");
