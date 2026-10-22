# Touch Mic

**A soft blob on your desk, with a USB-C cord. Touch it anywhere and Claude starts
listening. Let go and it stops.**

No buttons, no seams, no screen. A one-piece SLS TPU body with a floating outer
shell, filled with conductive foam that is simultaneously the capacitive
electrode and the compliant support. The only rigid thing inside is a
thumbnail-sized microcontroller that is also the USB-C port.

> Status: **concept proven end-to-end in software, no hardware built.**
> The host side works today on a real Mac: touching a key starts and stops
> Claude's own dictation, in the current conversation, with both tap and
> press-and-hold gestures. The device that will send that key does not exist yet.
> Start with [`docs/DECISIONS.md`](docs/DECISIONS.md) for why it is built this
> way, [`docs/RESEARCH.md`](docs/RESEARCH.md) for what has actually been verified
> and what has not, and [`hardware/BOM.md`](hardware/BOM.md) for the two-part
> bill of materials.

## Why not just use dictation software

Claude's own transcription does contextual correction — it is tuned for the
vocabulary you are actually using and takes hints from your project and branch
names. Routing through system dictation or a third-party app throws that away.
The whole point of this device is to reach **Claude's** dictation specifically,
which turned out to be harder than expected and is the subject of
[`host/README.md`](host/README.md).

## How it works

```
  finger
    |                     (capacitance couples through the TPU wall)
    v
[ soft TPU shell ]
[ conductive foam ] ----> XIAO SAMD21 pin A0   (hardware touch sensing)
                                 |
                                 v
                          USB-C ---> Mac, as a USB keyboard
                                 |
                                 v
                       holds F13 while touched
                                 |
                                 v
                    Hammerspoon presses Claude's
                    dictation control via the macOS
                    Accessibility API
```

The device does exactly one thing: **hold `F13` down while the body is being
touched, release it when it is not.** Every gesture falls out of that single
behaviour — a quick touch reads as tap-to-start, a sustained squeeze reads as
hold-to-talk.

## Layout

| Path | What's in it |
|---|---|
| [`firmware/`](firmware/) | CircuitPython for the XIAO SAMD21, with live tuning telemetry |
| [`host/`](host/) | The Hammerspoon config that presses Claude's dictation control |
| [`hardware/`](hardware/) | Bill of materials, and a parametric OpenSCAD test rig |
| [`docs/`](docs/) | Decision log and research, with sources and open questions |

## The one dependency that is not open

Everything here is open: the board is open hardware with published KiCad and
Eagle files, the firmware is CircuitPython and MIT-licensed libraries, the host
script is thirty lines of Lua you own.

The exception, stated plainly: **Claude's accessibility labels are not a
published API.** The final hop relies on a control called
`"Press and hold to record"` keeping that name. If a Claude update renames it,
`hs -c 'dictateProbe()'` says so immediately and the fix is one line — but it is
the only part of this stack that depends on somebody else's unversioned
decision.

## License

MIT — see [`LICENSE`](LICENSE).
