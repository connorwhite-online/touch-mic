// touch-mic — body with internals
//
// One piece. Outer form from profile.scad; the cavity is the same form with
// the plan drawn in by `wall`, the height dropped by `wall` and the top radius
// reduced by `wall`. That is an EXACT uniform offset — the wall is honest
// everywhere, which shelling an implicit surface could never give.
//
// Mounting, explicitly:
//   - XIAO sits flat on the floor in a bay of three walls, open toward the
//     USB aperture so the connector overhangs into it.
//   - Tactile switch sits in a square seat, located not glued.
//   - Plunger hangs from the crown directly over that seat.
//
//   openscad -D 'part="body"'    -o body.stl    body.scad
//   openscad -D 'part="layout"'  -o layout.stl  body.scad   // with dummy parts
//   openscad -D 'part="section"' -o section.stl body.scad

include <profile.scad>

part = "body";   // "body" | "section" | "layout" | "floorplan"

wall    = 2.0;
floor_t = 2.2;

/* [XIAO SAMD21] */
board_l  = 21.0;   // actual part; bay adds clearance
board_w  = 17.8;
board_t  = 1.2;    // PCB
conn_h   = 3.2;    // USB-C connector above the PCB
fit      = 0.5;    // clearance per side in the bay
rail_h   = 3.2;    // bay wall height: locates the PCB, clears the connector
rail_w   = 1.8;

/* [Switch] */
sw        = 6.0;   // 6x6 tactile switch
sw_seat_h = 1.6;
sw_seat_w = 1.2;   // seat wall; thinner keeps clearance to the board bay   // seat wall height: locates it, does not bury it
sw_body_h = 3.5;   // switch body
sw_act_h  = 0.8;   // actuator above the body
sw_x      = 12.0;
sw_y      = 12.5;

/* [Press] */
plunger_d = 7.0;
gap       = 0.8;   // pre-travel before the plunger meets the actuator

/* [Waist flexure] */
waist_z    = 2.6;
waist_h    = 4.2;
waist_wall = 1.0;  // thinned wall over the band. Lower = lighter press

// ---------------------------------------------------------------- derived

cav_h   = H - wall - floor_t;          // internal height
usb_dir = 180;                          // cable exits -x
usb_r   = rad(usb_dir);                 // outer radius on that bearing
usb_z   = floor_t + board_t + conn_h / 2;
usb_y   = -5.0;                         // aligned with the board
usb_w   = 9.6;
usb_t   = 3.6;
sw_top  = floor_t + sw_body_h + sw_act_h;
board_y  = -5.0;                        // clear of the switch quadrant
board_x0 = -(usb_r - wall - 0.5);       // PCB edge just inside the wall
board_cx = board_x0 + board_l / 2;

module cavity(off = wall) {
    solid(off, floor_t, H - off - floor_t, R_top - off, 0.1);
}

// ---------------------------------------------------------------- internals

// Three walls around the PCB. The fourth side is left open so the USB-C
// connector can overhang toward the aperture rather than fighting a wall.
module board_bay() {
    intersection() {
        cavity();
        translate([board_cx - (board_l + 2*fit + 2*rail_w)/2, board_y - (board_w + 2*fit + 2*rail_w)/2, floor_t])
            difference() {
                cube([board_l + 2 * fit + 2 * rail_w,
                      board_w + 2 * fit + 2 * rail_w, rail_h]);
                translate([rail_w, rail_w, -1])
                    cube([board_l + 2 * fit, board_w + 2 * fit, rail_h + 2]);
                // open the -x end for the connector
                translate([-1, rail_w, -1])
                    cube([rail_w + 1, board_w + 2 * fit, rail_h + 2]);
            }
    }
}

// A square seat that locates the switch without burying it.
module switch_seat() {
    intersection() {
        cavity();
        translate([sw_x, sw_y, floor_t])
            difference() {
                translate([-(sw / 2 + sw_seat_w), -(sw / 2 + sw_seat_w), 0])
                    cube([sw + 2*sw_seat_w, sw + 2*sw_seat_w, sw_seat_h]);
                translate([-(sw / 2 + 0.25), -(sw / 2 + 0.25), -1])
                    cube([sw + 0.5, sw + 0.5, sw_seat_h + 2]);
            }
    }
}

// Hangs from the crown. Intersecting a tall column with the cavity makes it
// meet the inner surface exactly, whatever the crown height is at that point.
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
            board_bay();
            switch_seat();
            plunger();
        }

        // Compliant waist: thin the flank over a band.
        intersection() {
            difference() { cavity(waist_wall); cavity(wall); }
            translate([0, 0, waist_z]) cylinder(h = waist_h, r = 300, $fn = 8);
        }

        // USB-C aperture. Length is wall + 6 and it starts just outside the
        // flank, so it stops inside the cavity. Cutting with a long cylinder
        // from far away punches straight through and leaves a second slot on
        // the opposite flank.
        translate([-(usb_r + 1.5), usb_y, usb_z])
            rotate([0, 90, 0])
                hull() {
                    translate([0,  (usb_w - usb_t) / 2, 0])
                        cylinder(h = wall + 6, d = usb_t, $fn = 32);
                    translate([0, -(usb_w - usb_t) / 2, 0])
                        cylinder(h = wall + 6, d = usb_t, $fn = 32);
                }

        // Service slot in the floor: stretch it open to fit the parts, and it
        // is the powder escape a closed cavity needs for SLS.
        translate([0, 0, -1])
            hull() {
                translate([ 2, 9, 0]) cylinder(h = floor_t + 2, d = 8, $fn = 32);
                translate([-6, 9, 0]) cylinder(h = floor_t + 2, d = 8, $fn = 32);
            }
        translate([-2, -11, -1]) cylinder(h = floor_t + 2, d = 4.5, $fn = 24);
    }
}

// Dummy parts, so the layout can be seen and checked rather than assumed.
module dummy_parts() {
    color("green")
        translate([board_cx - board_l / 2, board_y - board_w / 2, floor_t])
            cube([board_l, board_w, board_t]);
    color("green")
        translate([board_cx - board_l / 2 - 1.2, board_y - 4.4, floor_t + board_t])
            cube([3.0, 8.8, conn_h]);
    color("red")
        translate([sw_x - sw / 2, sw_y - sw / 2, floor_t])
            cube([sw, sw, sw_body_h]);
    color("red")
        translate([sw_x, sw_y, floor_t + sw_body_h])
            cylinder(h = sw_act_h, d = 3.5, $fn = 24);
}

// ---------------------------------------------------------------- render

if (part == "body") body();
else if (part == "section")
    difference() { body(); translate([-200, -200, -10]) cube([400, 200, 200]); }
else if (part == "layout") {
    difference() { body(); translate([-200, -200, -10]) cube([400, 200, 200]); }
    dummy_parts();
} else if (part == "lidoff") {
    difference() { body(); translate([-200, -200, 7.2]) cube([400, 400, 200]); }
} else if (part == "dummy_board") {
    translate([board_cx - board_l / 2, board_y - board_w / 2, floor_t])
        cube([board_l, board_w, board_t]);
    translate([board_cx - board_l / 2 - 1.2, board_y - 4.4, floor_t + board_t])
        cube([3.0, 8.8, conn_h]);
} else if (part == "dummy_switch") {
    translate([sw_x - sw / 2, sw_y - sw / 2, floor_t])
        cube([sw, sw, sw_body_h]);
    translate([sw_x, sw_y, floor_t + sw_body_h])
        cylinder(h = sw_act_h, d = 3.5, $fn = 24);
} else if (part == "floorplan")
    projection(cut = true) translate([0, 0, -(floor_t + 1.0)]) body();
else echo("set part to body, section, layout or floorplan");
