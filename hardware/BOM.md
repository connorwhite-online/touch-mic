# Bill of materials

One board, two printed files, one wire. Nothing to cut, nothing to fabricate.

| # | Part | Role | How you get it |
|---|---|---|---|
| 1 | Seeed XIAO SAMD21 | Touch sensing, USB-C, acts as a keyboard | ~$7, widely stocked |
| 2 | Electrode | Senses your finger | **Printed** — conductive PLA, file in this repo |
| 3 | Body | The soft shell | **Printed** — SLS TPU |
| 4 | One wire | A0 → electrode | Any hookup wire |

No PCB to design, no USB-C receptacle to source, no CC pull-down resistors, no
fasteners. Both printed parts can be ordered from the same place, so a builder
with no printer still gets everything in the mail.

## 1. XIAO SAMD21

The only small board with **hardware** capacitive touch (the SAMD21's Peripheral
Touch Controller) **and** native USB in one chip — no external resistors,
capacitors or sensing ICs. 21 × 17.8 mm, and the USB-C connector is already on
it, so the board *is* the port.

It also gives you a raw capacitance reading, which a fixed-function touch IC
like a TTP223 cannot. That is what makes the signal-strength logging in
[`firmware/code.py`](../firmware/code.py) possible, and it is why tuning this
device is measurement rather than guesswork.

Open hardware — Seeed publishes the full design package:

- [Schematic (PDF)](https://files.seeedstudio.com/wiki/Seeeduino-XIAO/res/Seeeduino-XIAO-v1.0-SCH-191112.pdf)
- [KiCad project](https://files.seeedstudio.com/wiki/Seeeduino-XIAO/res/XIAO_SAMD21_v2.1_SCH&PCB_20260304.zip)
- [Eagle project](https://files.seeedstudio.com/wiki/Seeeduino-XIAO/res/Seeeduino-XIAO-v1.0.zip)
- [3D model](https://files.seeedstudio.com/wiki/Seeeduino-XIAO/res/seeeduino-xiao-samd21-3d-model.zip) — needed for the CAD pocket
- [2D dimensions (DXF)](https://files.seeedstudio.com/wiki/Seeeduino-XIAO/res/102010328_Seeeduino_XIAO_Dimension.rar)
- [Wiki](https://wiki.seeedstudio.com/Seeeduino-XIAO/)

Stocked by [The Pi Hut](https://thepihut.com/products/seeed-xiao-samd21),
[Farnell](https://ie.farnell.com/seeed-studio/102010388/xiao-board-arm-arduino-board/dp/4060347),
[Universal Solder](https://www.universal-solder.ca/product/seeed-studio-xiao-samd21/)
and Seeed direct.

**Unverified:** which pins support QTouch. A
[reseller manual](https://shillehtek.com/blogs/shillehtek-product-manuals/seeeduino-xiao-samd21-arduino-board-presoldered-manual)
says A0, A6, A7; Seeed's own wiki does not list them. Single-source, so treat as
likely rather than certain. `touchio` settles it in seconds on arrival — the
firmware defaults to A0.

### Rejected alternatives

| Board | Why not |
|---|---|
| ESP32-S3 | Native touch and USB, but a radio chip — larger, thirstier, needs a USB-OTG mode switch |
| RP2040 | No hardware touch; falls back to software charge-timing with a 1 MΩ resistor |
| CH32V003 | No USB peripheral at all |
| TTP223 / AT42QT101x | Fixed-function: gives you a yes/no, not a number. No way to tune or debug |

## 2. The electrode — printed, not sourced

**Print it in Conductive PLA** from [`test-rig.scad`](test-rig.scad) (`part="puck"`),
and in the final device as the inner core.

This is a deliberate reversal of an earlier decision to use conductive foam.
Foam works electrically, but it ships as sheets, so somebody has to cut it —
which means the electrode's shape varies between builds, which means tuning
numbers don't transfer from one person's unit to the next. A printed electrode
is a file: identical geometry every time, no cutting, no sourcing ambiguity, and
orderable from the same service as the body.

In the finished device the same part does three jobs: it is the electrode, the
rigid core that anchors the board, and the thing the floating shell floats
around.

**Conductivity is not the constraint people expect.** You are not carrying
current — you are charging and discharging a plate at roughly 100 kHz, so what
matters is that the electrode's RC time constant stays well under a ~10 µs scan
cycle. The practical ceiling is around **30 kΩ** ([Capricate, UIST'15](https://mschmitz.org/publications/schmitz-UIST15-capricate.pdf)).

| Material | Typical resistivity | Verdict |
|---|---|---|
| Conductive PLA | ~15 Ω·cm | Comfortable — overqualified |
| Conductive PU foam | 10²–10⁵ Ω·cm | Works, but needs cutting |
| TPU-ESD | 10⁶–10⁹ Ω·cm | Marginal to dead |
| Dissipative (pink) foam | 10⁶–10⁹ Ω and up | No |

Order-of-magnitude figures, not datasheet values. The Conductive PLA number is a
typical vendor figure and has not been confirmed against the materialize.cc
catalogue.

**Home-printer fallback:** copper tape works fine and costs nothing if you
already have it. It is just less repeatable, so prefer the printed puck when
publishing numbers anyone else will rely on.

**Not possible, for the record:** printing the electrode as part of the TPU body.
SLS is one powder per build, there is no conductive TPU powder, and no
multi-material SLS. The electrode must be a separate part.

## 3. The body

SLS Flexible TPU. Design constraints:

- **1.0 mm minimum wall** (flexible walls distort during depowdering); 1.0–1.5 mm
  comfortable
- **Keep the sensing wall thin** — overlay thickness dominates sensitivity far
  more than electrode size does
- **Two escape holes ≥3.5 mm** at the low points of any trapped cavity; a
  floating shell is by definition a trap. The USB-C aperture can serve as one
- **Anchor the board to the core, never the floating shell** — otherwise plugging
  a cable in deflects the shell and false-triggers
- **Stretch-in slot** sized under the board so it pops through and the TPU closes
  around it — keeps the body one piece with no fasteners

For test coupons, ordinary FDM TPU filament is fine and much faster to iterate
on. Numbers will shift when you move to SLS, because SLS TPU is porous and
absorbs moisture — re-measure before freezing any geometry.

## Open risks

1. **Fractional sensitivity of a large electrode.** Big electrode, big baseline,
   small percentage change. Filling most of the volume may beat filling all of
   it. First thing the rig measures.
2. **Triboelectric static off SLS TPU.** A porous elastomer rubbed in dry air
   beside a high-impedance sense line. No SLS-TPU-specific data found anywhere.
   Mitigate with a series resistor on the sense line, a TVS diode and a ground
   guard. **Only shows up on a real printed part — the top unknown.**
3. **Moisture.** SLS parts are porous; absorbed moisture and skin oil shift the
   baseline. The firmware's drift tracking handles the slow component.
4. **Wire-to-puck contact.** The puck has a slot so a stripped wire end is
   trapped when it seats. Simple, but unproven — the serial telemetry shows
   intermittency immediately.
