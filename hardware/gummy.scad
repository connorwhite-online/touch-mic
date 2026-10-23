// touch-mic — bare form, for looking at. Internals live in body.scad.
//
//   openscad -D 'part="form"' -o gummy.stl gummy.scad

include <profile.scad>

part = "form";   // "form" | "plan" | "sectionX" | "sectionY"

if (part == "form") solid();
else if (part == "plan") plan_profile();
else if (part == "sectionX")
    difference() { solid(); translate([-200, -200, -10]) cube([400, 200, 200]); }
else if (part == "sectionY")
    difference() { solid(); translate([-200, -200, -10]) cube([200, 400, 200]); }
else echo("set part to form, plan, sectionX or sectionY");
