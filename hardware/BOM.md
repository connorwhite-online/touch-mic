# Bill of materials

Two parts and a print. Both parts are on Digi-Key, so it is one order.

| # | Item | Part | Digi-Key | Qty | ~Each |
|---|---|---|---|---|---|
| 1 | Microcontroller | [Seeed XIAO SAMD21](https://www.digikey.com/en/products/detail/seeed-technology-co-ltd/102010328/11506471) | `1597-102010328-ND` | 3 | $5.40 |
| 2 | Switch | [Same Sky TS02-66-50-BK-100-LCR-D](https://www.digikey.com/en/products/detail/same-sky-formerly-cui-devices/TS02-66-50-BK-100-LCR-D/15634294) | `2223-TS02-66-50-BK-100-LCR-D-ND` | 10 | ~$0.30 |
| 3 | Wire | 26–30 AWG stranded, two short lengths | — | — | — |
| 4 | Body | Printed from [`stl/body.stl`](stl/body.stl) | — | 1 | — |

Order three boards. They are $5 each and the first one you solder to is the
one you will want to change your mind about.

## Why Digi-Key and not Seeed

Seeed does not sell discrete tactile switches — their catalogue is boards and
Grove modules, so a Same Sky part number is not available there. Digi-Key is an
authorised Seeed distributor, which is why the XIAO is listed above, so one
Digi-Key order covers both. The reverse is not possible.

Seeed's own US warehouse page excludes the XIAO series from free shipping and
directs customers to authorised US distributors for faster delivery. Digi-Key
ships domestically from Minnesota, typically next day.

## Why this switch

| Requirement | This part | |
|---|---|---|
| Footprint | 6 × 6 mm | matches the seat |
| Height | 5.50 mm | accommodated; shortens the funnel |
| Travel | 0.25 mm typ (0.35 max) | the 0.8 mm gap clears it |
| Force | **100 gf** | the lightest 6 × 6 through-hole made |
| Life | 100,000 cycles | highest in the series — life rises as force falls |
| Mounting | through-hole | legs pass through the bridge; solder from below |

**Force was the deciding variable.** The 4.30 mm variant of this series would
have matched the CAD exactly, but only exists at 160 gf. Height is a free
parameter here — there is 10.8 mm of internal space and a taller switch simply
shortens the plunger — while force is not. So the shorter part was given up.

**Do not substitute a generic 6 × 6 switch.** Marketplace listings publish no
operating force, which is precisely the spec that decides whether the device
feels good. The 13-week figure on the Digi-Key page is the *manufacturer's*
lead time; stock was ~6,400, so it ships now. `LCR` was chosen over the
otherwise identical `SCR` for the same reason — `SCR` showed a 20-week lead.

## Rejected

| Option | Why not |
|---|---|
| TS38-9898-39-CL-450-SMT | 450 gf — roughly 3× a normal button. Also 9.85 mm and SMT |
| Tactile switch assortment | Varies by size and height, publishes no force at all |
| Omron D2F (~25 gf) | Genuinely lighter, but 12.8 × 6.5 mm — the pocket would need redrawing. The fallback if 100 gf feels stiff through TPU |
| USB-C extender | Relocates the port but adds bulk: the male plug protrudes ~7 mm from the XIAO. Insurance, not a requirement |

## Measure these when the parts arrive

Two numbers in the CAD are inferred from the series norm rather than read off a
datasheet. Both are small and both break the fit if wrong.

- **Pin span** — `leg_span` is 7.0 mm. If it is off, the relief slots miss and
  the switch will not seat.
- **Body/actuator split** — assumed 3.5 mm body plus 2.0 mm actuator to make up
  the stated 5.50 mm. This sets the plunger length and the pre-travel gap.

## The body

One piece, SLS Flexible TPU, 47.1 × 47.4 × 15.0 mm.

- **1.0 mm minimum wall** for SLS TPU; the thinnest feature here is the 0.8 mm
  hinge ring, which is deliberately below that and needs checking on a print
- **Open underside** apart from a 3.6 mm rim — this is the assembly access and
  the powder escape both
- **No openings in the top skin.** All flexure is thickness varied from inside

FDM TPU is fine for checking fit and feel, but it is layer-bonded and
anisotropic where SLS is closer to isotropic. The ranking of stiffnesses
transfers; the absolute feel does not.

## Open risks

1. **Does 100 gf feel right through the hinge?** The user's force is 100 gf
   *plus* whatever the TPU costs, and that surcharge is unmeasured. The pad
   travels 1.05 mm, which is a lot for a 0.8 mm hinge over a 2.5 mm span.
2. **Deliberate preload is not available.** SLS holds about ±0.3 mm while switch
   travel is 0.25 mm, so the variation exceeds the whole stroke. Force
   reduction belongs to the hinge — thinner, wider, or a larger pad.
3. **Sharp thickness steps** at 1.8 → 0.8 → 2.0 mm. Stress concentrations, and
   the hinge is where it will fatigue. Worth chamfering once the force is right.
