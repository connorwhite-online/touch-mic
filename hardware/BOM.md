# Bill of materials

Two parts and a print. Every component is off-the-shelf and multi-sourced.

| # | Part | Role | Approx. |
|---|---|---|---|
| 1 | Seeed XIAO SAMD21 | Hardware capacitive touch, native USB-C, acts as a keyboard | ~$7 |
| 2 | Black conductive PU foam | Electrode **and** compliant support **and** electrical contact | pennies |
| 3 | SLS Flexible TPU print | The body | quote |

No PCB to design, no USB-C receptacle to source, no CC pull-down resistors to
get right, no fasteners, no solder joint — if the foam-on-pad contact holds.

## 1. XIAO SAMD21

Chosen because it is the only small board that has **hardware** capacitive touch
(the SAMD21's Peripheral Touch Controller) **and** native USB in one chip, with
no external resistors, capacitors or sensing ICs required. 21 × 17.8 mm, and the
USB-C connector is already on it, so the board *is* the port.

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
likely rather than certain. CircuitPython's `touchio` settles it in seconds on
arrival — the firmware defaults to A0.

### Rejected alternatives

| Board | Why not |
|---|---|
| ESP32-S3 | Native touch and USB, but it is a radio chip — larger, thirstier, and needs a USB-OTG mode switch |
| RP2040 | No hardware touch; `touchio` falls back to software charge-timing with a 1 MΩ resistor |
| CH32V003 | No USB peripheral at all |
| AT42QT1011/1012 + separate MCU | Robust two-chip production path, but two chips where one will do |

## 2. Black conductive foam — read this before buying

Two very different products are both sold as "anti-static foam":

| Type | Colour | Resistance | Use it? |
|---|---|---|---|
| **Conductive** | **Black** | 10³–10⁶ Ω | **Yes** |
| Dissipative | Pink | 10⁶–10⁹ Ω and up | No |

**The pink one is far more common and will not work.** The arithmetic: the
electrode is charged and discharged at roughly 100 kHz, so its RC time constant
must stay well under a ~10 µs scan cycle. For a ~40 mm electrode at ~50 pF:

| Material | Typical resistivity | Rough RC | Verdict |
|---|---|---|---|
| Conductive PU foam | 10²–10⁵ Ω·cm | ~125 ns | Comfortable |
| TPU-ESD, good grade | ~10⁶ Ω·cm | ~12 µs | Marginal |
| TPU-ESD, poor grade | ~10⁹ Ω·cm | ~12 ms | Dead |

Order-of-magnitude estimates, not datasheet values — but the shape of the answer
is robust. Look for a volume resistance spec per **ANSI/ESD STM11.12**.

- [RS PRO ESD foam](https://uk.rs-online.com/web/p/anti-static-packaging/8153509) — stocks both types, check each SKU
- [Desco conductive foam](https://www.electronicsdatasheets.com/parts/desco-industries-inc/12667) — reliable brand to search for at Digi-Key
- [Protektive Pak pink dissipative](https://www.gotopac.com/protektive-pak-dissipative-foam-pink.html) — linked as what *not* to buy

Cheapest source of all: the black foam ICs ship stuck into.

**Printed conductive alternatives were considered and rejected** — see
[`docs/DECISIONS.md`](../docs/DECISIONS.md). Catalogue check on
materialize.cc returned exactly one conductive material (Conductive PLA, FDM,
rigid) and no conductive SLS powder of any kind.

## 3. The print

SLS Flexible TPU. Design constraints:

- **1.0 mm minimum wall** (flexible walls distort during depowdering); 1.0–1.5 mm
  is the comfortable range
- **Keep the sensing wall thin** — overlay thickness dominates sensitivity far
  more than electrode size does
- **Two escape holes ≥3.5 mm** at the low points of any trapped cavity; a
  floating shell is by definition a trap. The USB-C aperture can serve as one
- **Anchor the board to the core, never the floating shell**
- **Stretch-in slot** sized under the board so it pops through and the TPU closes
  around it — keeps the body one piece with no fasteners

## Open risks

1. **Foam-on-pad contact reliability.** Elegant, and conductive foam is used as a
   grounding gasket in real products, but compressed contact is less bulletproof
   than solder. Fallback is one short wire. The serial telemetry shows
   intermittency immediately.
2. **Fractional sensitivity of a full-volume electrode.** Large electrode, large
   baseline, small percentage change. May need to fill most rather than all.
3. **Triboelectric static off SLS TPU.** Rubbing a porous elastomer in dry air
   next to a high-impedance sense line. No SLS-TPU-specific data was found.
   Mitigate with a series resistor on the sense line, a TVS diode, and a ground
   guard. **Only shows up on a real printed part — the top unknown.**
4. **Moisture.** SLS parts are porous; absorbed moisture and skin oil shift the
   dielectric baseline. The firmware's drift tracking handles the slow component.
