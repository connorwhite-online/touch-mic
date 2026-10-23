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
board_y = -10.0;   // pushed clear of the dish quadrant

/* [Switch] */
sw        = 6.0;
sw_seat_w = 1.2;
// Through-hole legs protrude ~3.5mm below the body. Without relief the
// switch bottoms out on the bridge and never seats. Slots let the pins pass
// into the open underside, where the wires can be soldered after seating.
leg_span  = 7.0;   // across the pin rows
leg_slot_w = 2.2;
leg_slot_l = 8.5;
sw_seat_h = 1.6;
// Same Sky TS02-66-50-BK-100-LCR-D: 6x6 body, 5.50mm total height, 100 gf.
// Chosen for force, not height: the 4.30mm variant of this series only comes
// at 160 gf, and height is free here while force is not.
// The body/actuator split is inferred from the series' typical 3.5mm body;
// confirm against the datasheet when the part arrives.
sw_body_h = 3.5;
sw_act_h  = 2.0;   // 3.5 + 2.0 = 5.50mm total
sw_x      = 9.0;
sw_y      = 7.0;

/* [Press] */
plunger_d = 7.0;
gap       = 0.8;

/* [Touch dish] */
// A gently indented pad in the flat-ish top face, inboard of the edge. The
// rim stays full thickness and stiff; only the dish floor flexes. This
// replaces the waist flexure: the whole shell no longer has to move, so an
// edge press cannot tilt it and a knock on the flank does nothing.
dish_d     = 15.0;   // the visible indent, across
dish_depth = 1.3;    // how far it dips below the top face
// The outer skin is CONTINUOUS -- no slots, no gaps. All flexure is thickness
// varied from the inside, in three zones:
//   pad    thick, stiff: moves as a piston rather than bowing
//   hinge  thin ring around it: this is what actually bends
//   wall   full thickness beyond: rigid surround
pad_d      = 10.0;   // stiff piston
hinge_od   = 15.0;   // hinge ring outer diameter (matches the dish edge)
pad_t      = 1.8;    // material over the pad
hinge_t    = 0.8;    // material over the hinge -- THE force dial
funnel_d   = 8.5;    // top of the funnel under the pad

// ---------------------------------------------------------------- derived

bridge_x = 9.0;    // runs under the switch, along y

usb_dir  = 180;
usb_r    = rad(usb_dir);
usb_z    = base_z + board_t + conn_h / 2;
usb_w    = 9.6;
usb_t    = 3.6;
sw_top   = floor_t + sw_body_h + sw_act_h;
board_x0 = -(usb_r - wall - 0.5);
board_cx = board_x0 + board_l / 2;

// A spherical cap of depth dish_depth across dish_d.
function dish_R() = ((dish_d * dish_d) / 4 + dish_depth * dish_depth) / (2 * dish_depth);

module dish_cut(drop = 0) {
    translate([sw_x, sw_y, H - dish_depth + dish_R() - drop])
        sphere(r = dish_R(), $fn = 96);
}

// The volume BELOW the cap surface dropped by `drop`, within a disc or
// annulus. Not the shifted sphere itself: a sphere's interior lies ABOVE its
// lowest point, so subtracting that removes the skin rather than the space
// under it.
module zone(d_outer, d_inner, drop) {
    difference() {
        translate([sw_x, sw_y, -1])
            difference() {
                cylinder(h = H + 1, d = d_outer, $fn = 96);
                if (d_inner > 0)
                    translate([0, 0, -1]) cylinder(h = H + 3, d = d_inner, $fn = 96);
            }
        dish_cut(drop);
    }
}

module cavity(off = wall) {
    solid(off, floor_t, H - off - floor_t, R_top - off, 0.1);
}

// A bridge spanning the open underside, rim to rim. This is the load path:
// the plunger pushes DOWN on the switch, so the switch needs backing, and
// with no floor the only way to get it is a bar anchored at both ends.
// Oversized in x so it runs past the wall on both sides and joins the shell.
module bridge() {
    difference() {
        union() {
            intersection() {
                difference() { solid(); cavity(); }
                translate([bridge_x - bridge_w / 2, -60, 0])
                    cube([bridge_w, 120, floor_t]);
            }
            intersection() {
                linear_extrude(height = floor_t) plan_profile();
                translate([bridge_x - bridge_w / 2, -60, 0])
                    cube([bridge_w, 120, floor_t]);
            }
        }
        // leg relief: pins pass through into the open underside, where the
        // wires can be soldered with the switch already seated
        for (sx = [-1, 1])
            translate([sw_x + sx * leg_span / 2 - leg_slot_w / 2,
                       sw_y - leg_slot_l / 2, -1])
                cube([leg_slot_w, leg_slot_l, floor_t + 2]);
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

// Funnels from the underside of the stiff pad down to a short plunger on the
// switch. Tapered so the pad's area is gathered into the actuator rather than
// loading the skin in bending.
module plunger() {
    pad_under = H - dish_depth - pad_t;
    top_z     = sw_top + gap;
    translate([sw_x, sw_y, top_z])
        cylinder(h = pad_under - top_z, d1 = plunger_d, d2 = funnel_d, $fn = 64);
}

// ---------------------------------------------------------------- body

module body() {
    union() {
        difference() {
            union() {
                difference() { solid(); cavity(); }
                board_bay();
                switch_seat();
            }

            // open underside, leaving the perimeter rim
            translate([0, 0, -1])
                linear_extrude(height = floor_t + 1)
                    offset(r = -rim_w) plan_profile();

                // leg relief through the bridge
            for (sx = [-1, 1])
                translate([sw_x + sx * leg_span / 2 - leg_slot_w / 2,
                           sw_y - leg_slot_l / 2, -1])
                    cube([leg_slot_w, leg_slot_l, floor_t + 2]);

        // the indent itself, then the two thickness zones under it
            dish_cut();
            zone(pad_d, 0, pad_t);
            zone(hinge_od, pad_d, hinge_t);

            // USB-C aperture. Starts just outside the flank and stops inside
            // the cavity; a long cut from far away punches straight through.
            translate([-(usb_r + 1.5), board_y, usb_z])
                rotate([0, 90, 0])
                    hull() {
                        translate([0,  (usb_w - usb_t) / 2, 0])
                            cylinder(h = wall + 6, d = usb_t, $fn = 32);
                        translate([0, -(usb_w - usb_t) / 2, 0])
                            cylinder(h = wall + 6, d = usb_t, $fn = 32);
                    }
        }
        bridge();
        plunger();
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
