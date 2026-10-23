# Bill of materials

| # | Part | Role | How you get it |
|---|---|---|---|
| 1 | Seeed XIAO SAMD21 | USB-C, acts as a keyboard | ~$7, widely stocked |
| 2 | One tactile switch | Detects the press | ~$0.10, universally available |
| 3 | Body | The soft shell, and the button | **Printed** — one piece, SLS TPU |
| 4 | Two short wires | Switch → GPIO and GND | Any hookup wire |

Two solder joints. No PCB, no USB-C receptacle, no CC resistors, no electrode,
no conductive material, no fasteners, no assembly beyond seating the board.

## How the body becomes the button

The outer shell is carried on a thin continuous skirt. Press anywhere on it and
the shell translates downward; a plunger hanging from its underside passes
through a hole in the base and actuates a single switch. "Press anywhere" is
mechanical, not electrical.

A **continuous skirt** rather than discrete ribs, because it supports the whole
perimeter — pressing near the rim translates the shell instead of tilting it.
Tilt is the failure mode that would break press-anywhere, and it is what
[`test-rig.scad`](test-rig.scad) (`part="press"`) exists to measure.

## 1. XIAO SAMD21

21 × 17.8 mm with the USB-C connector already on it, so the board *is* the port.
Native USB means it enumerates as a keyboard with no extra hardware.

Open hardware — Seeed publishes the full package:

- [Schematic (PDF)](https://files.seeedstudio.com/wiki/Seeeduino-XIAO/res/Seeeduino-XIAO-v1.0-SCH-191112.pdf)
- [KiCad project](https://files.seeedstudio.com/wiki/Seeeduino-XIAO/res/XIAO_SAMD21_v2.1_SCH&PCB_20260304.zip)
- [3D model](https://files.seeedstudio.com/wiki/Seeeduino-XIAO/res/seeeduino-xiao-samd21-3d-model.zip) — needed for the CAD pocket
- [Wiki](https://wiki.seeedstudio.com/Seeeduino-XIAO/)

Stocked by [The Pi Hut](https://thepihut.com/products/seeed-xiao-samd21),
[Farnell](https://ie.farnell.com/seeed-studio/102010388/xiao-board-arm-arduino-board/dp/4060347),
[Universal Solder](https://www.universal-solder.ca/product/seeed-studio-xiao-samd21/),
Seeed direct.

Note: the board's hardware capacitive touch is no longer used. It is still the
right board — small, USB-C, native HID — but any USB-capable microcontroller
would now do.

## 2. The switch

A standard 6 × 6 mm tactile switch, wired between any GPIO and GND with the
internal pull-up enabled. Lower actuation force is better; around 50 gf is
typical and anything lighter helps.

This is the most available component in existence. There is no sourcing
guidance to give beyond "buy a tactile switch."

## 3. The body

One piece, SLS Flexible TPU. Design constraints:

- **1.0 mm minimum wall** — flexible walls distort during depowdering; 1.0–1.5 mm
  comfortable
- **Two escape holes ≥3.5 mm** per cavity, at the low points in the cleaning
  orientation. The shell cavity is a powder trap by definition; the plunger
  clearance hole serves as one
- **Anchor the board to the base, never the floating shell** — otherwise plugging
  in a cable deflects the shell and false-triggers
- **Stretch-in slot** sized under the board so it pops through and the TPU closes
  around it — keeps the body one piece with no fasteners

FDM TPU is fine for iterating on the press feel, but it is anisotropic and
layer-bonded where SLS is closer to isotropic, so the *ranking* of stiffnesses
will transfer and the absolute feel will not. Confirm on SLS before freezing.

## Open risks

1. **Edge-press tilt.** Pressing the rim may tilt the shell rather than
   translating it, so the plunger misses. The whole point of the press coupon.
   If the skirt alone can't solve it, the fallbacks are a stiffer shell on a
   softer skirt, or a dome that buckles.
2. **Travel and feel.** Too little travel feels dead, too much feels vague.
   Tune `skirt_t` and `skirt_h` in the rig.
3. **Flexure fatigue.** TPU flexures are durable and the switch is rated for
   100k+ cycles, but neither has been cycled here.

## What this BOM used to say

Earlier revisions specified a capacitive electrode — first conductive foam, then
conductive PLA, then conductive TPU. All of that is gone. A mechanical switch
removed the electrode entirely and with it every sourcing problem, the
triboelectric risk, the moisture drift, the calibration, and the conflict
between "conductive" and "SLS". See [`docs/DECISIONS.md`](../docs/DECISIONS.md).
