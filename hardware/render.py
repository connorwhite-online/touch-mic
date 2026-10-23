"""Studio renders of the touch-mic body. Blender 3.4, headless.

  blender -b -P render.py -- <input.stl> <outdir>
"""
import bpy
import sys
import math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
STL = argv[0]
OUT = argv[1]

SAMPLES = 110
RES = (1200, 880)


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def setup_render():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = RES
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Filmic"
    sc.view_settings.look = "Medium High Contrast"
    # Try GPU, fall back silently to CPU.
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for backend in ("METAL", "OPTIX", "CUDA"):
            try:
                prefs.compute_device_type = backend
                prefs.get_devices()
                if any(d.type == backend for d in prefs.devices):
                    for d in prefs.devices:
                        d.use = d.type in (backend, "CPU")
                    sc.cycles.device = "GPU"
                    print(f"[render] GPU backend: {backend}")
                    break
            except Exception:
                continue
    except Exception:
        pass


def load_object():
    bpy.ops.import_mesh.stl(filepath=STL)
    ob = bpy.context.selected_objects[0]
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    # Move to the world origin BEFORE scaling: scaling happens about the
    # object's origin, so leaving it out in space shrinks the mesh toward a
    # point metres above the floor and the camera frames nothing.
    ob.location = (0, 0, 0)
    # Normalise so the longest edge is 1 unit; everything else is sized to that.
    dims = ob.dimensions
    s = 1.0 / max(dims)
    ob.scale = (s, s, s)
    bpy.ops.object.transform_apply(scale=True)
    # Sit it on the floor.
    zmin = min((ob.matrix_world @ Vector(c))[2] for c in ob.bound_box)
    ob.location.z -= zmin
    bpy.ops.object.shade_smooth()
    ob.data.use_auto_smooth = True
    ob.data.auto_smooth_angle = math.radians(60)
    return ob


def gummy_material(name, base, sss, sss_radius, rough, transmission=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = base
    b.inputs["Subsurface"].default_value = sss
    b.inputs["Subsurface Color"].default_value = base
    b.inputs["Subsurface Radius"].default_value = sss_radius
    b.inputs["Roughness"].default_value = rough
    b.inputs["IOR"].default_value = 1.45
    b.inputs["Transmission"].default_value = transmission
    b.inputs["Specular"].default_value = 0.4
    return m


def studio(bg=0.055, k=1.0):
    # Seamless backdrop: a big plane, curved up behind via a bent grid would be
    # nicer, but a plane plus a graded world reads clean at this crop.
    bpy.ops.mesh.primitive_plane_add(size=24)
    floor = bpy.context.object
    fm = bpy.data.materials.new("floor")
    fm.use_nodes = True
    fb = fm.node_tree.nodes["Principled BSDF"]
    fb.inputs["Base Color"].default_value = (0.10, 0.10, 0.105, 1)
    fb.inputs["Roughness"].default_value = 0.52
    fb.inputs["Specular"].default_value = 0.25
    floor.data.materials.append(fm)

    world = bpy.data.worlds.new("w")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (bg, bg, bg * 1.08, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0

    def area(loc, rot, size, energy, color=(1, 1, 1)):
        bpy.ops.object.light_add(type="AREA", location=loc, rotation=rot)
        L = bpy.context.object
        L.data.size = size
        L.data.energy = energy
        L.data.color = color
        return L

    # Key: large and close, so highlights roll off softly on a round form.
    area((-1.9, -1.7, 2.4), (math.radians(38), 0, math.radians(-46)), 4.0, 420 * k)
    # Fill: dimmer, opposite side, keeps the shadow side from going black.
    area((2.4, -1.4, 1.2), (math.radians(62), 0, math.radians(58)), 3.2, 110 * k)
    # Rim: behind and low, separates the silhouette from the backdrop.
    area((0.9, 2.6, 1.1), (math.radians(104), 0, math.radians(188)), 2.4, 230 * k,
         color=(0.92, 0.95, 1.0))


def camera(loc, look_at=(0, 0, 0.17), lens=58, fstop=2.6):
    bpy.ops.object.camera_add(location=loc)
    cam = bpy.context.object
    cam.data.lens = lens
    d = Vector(look_at) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam.data.dof.use_dof = True
    cam.data.dof.focus_distance = d.length
    cam.data.dof.aperture_fstop = fstop
    bpy.context.scene.camera = cam
    return cam


def render_to(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print(f"[render] wrote {path}")


SHOTS = [
    # name, camera, (base, sss, radius, rough, transmission), light scale, exposure
    ("gummy-hero", (1.25, -1.55, 0.78),
     ((0.84, 0.26, 0.05, 1), 0.72, (0.52, 0.18, 0.06), 0.20, 0.30), 0.80, -0.35),
    ("gummy-low", (1.75, -0.95, 0.34),
     ((0.84, 0.26, 0.05, 1), 0.72, (0.52, 0.18, 0.06), 0.20, 0.30), 0.80, -0.35),
    ("gummy-top", (0.55, -1.05, 1.45),
     ((0.84, 0.26, 0.05, 1), 0.72, (0.52, 0.18, 0.06), 0.20, 0.30), 0.80, -0.35),
    ("satin-hero", (1.25, -1.55, 0.78),
     ((0.022, 0.022, 0.027, 1), 0.08, (0.04, 0.04, 0.05), 0.42, 0.0), 0.45, -0.55),
]

for name, campos, mat, kscale, exposure in SHOTS:
    clear()
    setup_render()
    bpy.context.scene.view_settings.exposure = exposure
    ob = load_object()
    base, sss, radius, rough, trans = mat
    ob.data.materials.clear()
    ob.data.materials.append(
        gummy_material(name, base, sss, radius, rough, trans))
    studio(k=kscale)
    camera(campos)
    render_to(f"{OUT}/{name}.png")

print("[render] done")
