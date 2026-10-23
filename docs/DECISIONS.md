# Decisions

Why this is built the way it is, including the routes that were tried and
abandoned. Dates are when the decision was made, not when it was written up.

## 2026-10-22 — Target Claude's own dictation, not system or third-party

**Decided:** reach Claude's own dictation rather than macOS Dictation, Wispr
Flow (already installed on the dev machine) or superwhisper.

**Why:** Claude's transcription does contextual correction. Claude Code's own
docs state it is tuned for coding vocabulary and that the current project name
and git branch name are added as recognition hints automatically. Routing audio
through anything else discards that, which defeats the purpose of the device.

**Cost of this decision:** no public API reaches it. See the two attempts below.

## 2026-10-22 — The `dictationShortcut` config route is a dead end

**Tried:** Claude Desktop's settings schema contains three separate shortcut
keys, discovered by reading `app.asar`:

| Setting | Default | Accepts |
|---|---|---|
| `quickEntryShortcut` | `"double-tap-option"` | `"off"`, `{accelerator}` |
| `quickEntryDictationShortcut` | `"off"` | `"capslock"`, `"double-tap-capslock"`, `{accelerator}` |
| `dictationShortcut` | `"default"` | `"off"`, `{accelerator}` |

`dictationShortcut` accepts an arbitrary Electron accelerator and is not a Quick
Entry setting, which made it look like the clean route.

**Result: it does not work, and not because of a mistake in setting it.** The
value was written to `~/Library/Application Support/Claude/config.json` while
the app was stopped (writing it while running risks the app overwriting it on
quit), and it survived a relaunch intact. But the app never registers a handler:
`~/Library/Logs/Claude/main.log` shows dozens of startup registrations and no
dictation or global-shortcut entry, and pressing the accelerator does nothing.

**Why:** the feature is gated behind `dictationEnabled`, which the bundle marks
`visibility: "public-undocumented"`, `executionTarget: "desktop"`,
`remotePolicy.hotApplied: true`. Feature flags arrive via GrowthBook
(`[growthbook] loaded 455 features` at startup). It is off for this account and
cannot be changed client-side. Claude Desktop exposes no voice-shortcut UI in
this build, and claude.ai exposes none either.

**Do not retry this route.** [`host/set-claude-dictation-shortcut.sh`](../host/set-claude-dictation-shortcut.sh)
is kept only so the setting can be cleared, and so the next person can confirm
the negative result cheaply. If the flag ever flips on, the setting is already
understood.

## 2026-10-22 — Press the control via the Accessibility API

**Decided:** drive Claude's dictation control directly through macOS
Accessibility, from Hammerspoon.

**Why Hammerspoon over `osascript`:** one app-scoped Accessibility grant, rather
than handing a general-purpose scripting interpreter control of the whole UI.
It is also the final deliverable — the thing that listens for `F13` — so it is
one dependency instead of two.

Details and the traps that cost the most time are in
[`host/README.md`](../host/README.md). This works today, including dictating
into the current conversation rather than a new chat — something the Quick Entry
route could never do.

## 2026-10-22 — The device sends one key, held

**Decided:** the hardware holds `F13` down while touched and releases on let-go.
Nothing else.

**Why `F13`:** no ordinary keyboard has one, so nothing on the Mac can collide
with it, and no application will see a stray keystroke it recognises.

**Why held rather than tapped:** it collapses two gestures into one firmware
behaviour. The host resolves a press shorter than 0.35 s as tap-to-start (stays
recording, tap again to stop) and anything longer as hold-to-talk (stops on
release). Both confirmed working. Claude's own Code-tab control is natively
labelled `"Press and hold to record"`, so hold is the gesture the platform was
designed around.

**Consequence:** the hardware is decoupled from the host entirely. If the
Accessibility route ever breaks, the device still sends `F13` and only
`host/init.lua` changes.

## 2026-10-22 — SLS TPU, one piece, floating shell

**Decided:** one-piece SLS Flexible TPU body — outer shell on compliant
supports around a rigid-ish core that anchors the board.

**Why:** the industrial design intent is a soft blob with a cord, approachable
and seamless. SLS TPU is the only process that gives organic geometry, a gummy
tactile surface and internal compliant structure in a single part. Compliant
lattices are the signature SLS TPU application.

**Hard constraint discovered:** the USB-C connector must anchor to the rigid
core, never the floating shell. Otherwise inserting a cable deflects the shell —
a guaranteed false trigger — and the cable's weight permanently preloads the
supports.

**Print constraints:** 1.0 mm minimum wall for TPU 90A (above the nylon figure,
because flexible walls distort during depowdering); any powder-trapping cavity
needs two escape holes ≥3.5 mm at the low points in the cleaning orientation.
A floating shell is by definition a powder trap.

## 2026-10-22 — Conductive foam as electrode, support and contact

**Decided:** black conductive polyurethane foam filling the interior, pressed
directly against the board's A0 pad.

**Why foam over the alternatives:**

- **Conductive filament is impossible here.** SLS is one powder per build; there
  is no conductive TPU powder and no multi-material SLS. Conductive PLA exists
  but is FDM and rigid, which puts a hard lump inside a soft object.
- **Silver ink lining** would work electrically (ACI SS1109 is formulated for
  TPU, >200% elongation) but you cannot reach inside a one-piece shell to apply
  it. It fights the thing the design most wants to be.
- **Foam does three jobs at once:** it is the electrode, it is the compliant
  support for the floating shell, and compressed against the pad it is also the
  electrical contact — removing the wire, the solder joint and a part.

**Why "touch anywhere" needs volume, not a pad:** the electrode has to sit a few
millimetres from every point of the shell. A central disc gives a strong centre
and a dead perimeter. Filling the interior solves this by construction.

**The trap that makes or breaks this:** conductive (black, 10³–10⁶ Ω) and
dissipative (pink, 10⁶–10⁹ Ω) foam are both sold as "anti-static foam". The pink
one is far more common and is too resistive to work. See
[`hardware/BOM.md`](../hardware/BOM.md) for the arithmetic.

**Known tension, unresolved until tested:** a large electrode buys reach but
costs fractional sensitivity. Filling the whole interior may give ~50–100 pF
baseline against a 1–5 pF finger, a 2–5 % change. The answer may be filling most
of the volume rather than all of it. This is the first thing the test rig must
measure.

## 2026-10-22 — Reversal: printed electrode, not foam

**Supersedes the foam decision above.** Foam is retained in
[`hardware/BOM.md`](../hardware/BOM.md) only as a fallback.

**Why the reversal:** foam fails the project's actual goal, which is that a
stranger can reproduce this. It ships as sheets, so somebody cuts it; hand-cut
electrodes vary in shape; varying shape means varying baseline capacitance;
which means tuning numbers published here would not transfer to anyone else's
build. It also cannot be specified as a part number — "black conductive foam" is
a category containing a trap (the far more common pink dissipative grade is too
resistive to work).

**What replaces it:** a Conductive PLA puck, printed from
[`hardware/test-rig.scad`](../hardware/test-rig.scad). The electrode stops being
something you source and becomes a file — identical every time, no cutting, and
orderable from the same service as the body. In the finished device the same
part is also the rigid core that anchors the board and that the floating shell
floats around.

**Cost of the reversal:** the electrode is rigid rather than soft. Acceptable,
because the core had to be rigid anyway to anchor the USB-C connector — the
compliance comes from the printed TPU ribs, which is where the original
floating-shell concept put it.

**General principle this established:** for an open-source device, prefer a part
that is a *file* over a part that is *bought and modified*. Reproducibility beats
bench convenience.

## 2026-10-22 — Drop capacitive sensing entirely; use a tactile switch

**Supersedes every electrode decision above.** There is no electrode any more.

**Why:** the premise was never examined. The project opened with the words
"capacitive touch sensor" and that was taken as a requirement rather than an
option. It isn't one — the device only needs to know *you are touching it*, and
a switch answers that question with a commodity part.

What a switch deleted, in one move:

| Problem | Status |
|---|---|
| Electrode material (three reversals: foam → PLA → TPU) | Gone — no electrode |
| Single-vendor $80 conductive filament | Gone |
| Triboelectric static into the GPIO | Gone |
| Moisture and humidity baseline drift | Gone |
| Fractional sensitivity of a large electrode | Gone |
| Threshold tuning, noise floor, calibration | Gone |
| "Conductive material is FDM-only" vs "body must be SLS" | Gone — SLS restored |

Every open risk previously listed in `hardware/BOM.md` was a capacitive problem.

**The original concept was already mechanical.** The floating shell on
compressible supports, described early on, is a plunger. The design had a button
in it from the start; the only assumption was that the thing underneath had to
sense capacitance.

**What is lost:** zero-force actuation. Capacitive responds to a feather touch;
a switch needs real pressure. For a dictation trigger sitting on a desk,
deliberate pressure is arguably a feature — it cannot fire when brushed past.

**What is unchanged:** the entire host side. The device still holds `F13`,
Hammerspoon still presses Claude's dictation control, both gestures still work.
That chain was always independent of how the device decides it is being touched.

**Lesson worth keeping:** three reversals were spent optimising a component that
should not have existed. When a sub-problem keeps resisting, check whether it is
load-bearing before solving it again.
