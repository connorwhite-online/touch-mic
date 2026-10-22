# Firmware

[`code.py`](code.py) — CircuitPython for the XIAO SAMD21. Holds `F13` down while
the body is touched, releases on let-go, and prints live telemetry so the
electrode and geometry can be tuned against real numbers.

## Install

1. Plug the XIAO in, double-tap its reset pad, drag the CircuitPython `.uf2`
   onto the drive that appears
2. Copy `code.py` to the `CIRCUITPY` drive
3. Copy the `adafruit_hid` folder into `CIRCUITPY/lib/`
   ([Adafruit_CircuitPython_HID](https://github.com/adafruit/Adafruit_CircuitPython_HID), MIT)
4. Open the serial console: `screen /dev/tty.usbmodem*`, or Mu's REPL

## Wiring

One connection: **pin A0 to the conductive foam.** Ideally the foam is simply
compressed against the A0 pad by the TPU core, with no wire at all.

## How it works

Four ideas, no electronics background required.

**The chip measures capacitance and hands you a number.** `touch.raw_value` is a
count — bigger means more capacitance, which means something conductive is near
the electrode. Your body is conductive. There is no switch and nothing
mechanical.

**The resting level is measured, not assumed.** What the sensor reads untouched
depends on foam size, wall thickness, humidity and the cable. The code averages
32 samples at startup to establish `baseline`. From then on only `delta` matters
— how far above rest the current reading sits. A finger may move it only a few
percent, so you always watch the change, never the absolute.

**The resting level drifts, and ignoring that breaks it.** Temperature, humidity,
foam relaxing and TPU absorbing moisture all nudge it over minutes. Lock the
baseline at startup and the button eventually goes deaf or jams on. So the
baseline creeps toward the current reading — but **only while untouched**, so it
can never slowly forget a finger that is really there.

**Two thresholds, not one.** A single threshold would chatter on and off many
times a second when the signal hovers near it, machine-gunning dictation. So it
triggers at `+120` and will not release until it falls below `+70` — the same
trick a thermostat uses. That gap is hysteresis.

The rest is safety: `MAX_HOLD` stops a stuck reading jamming the key down
forever, and the `finally:` block releases the key even if the program crashes.
Without it, a crash mid-touch leaves `F13` permanently held.

## Tuning

```
raw= 1847 base= 1840 delta=   +7
raw= 2104 base= 1840 delta= +264 ##########################
TOUCH   delta=264
RELEASE peak=312  held=1.84s
```

**What good looks like:** a touch anywhere on the body producing a couple of
hundred counts against idle noise of maybe ±10.

**What failure looks like:** a touch on the far edge of the blob moving it 20
counts while noise is ±10. That spot will not work reliably — and that number,
not a yes/no, is what tells you whether "touch anywhere" is real or whether the
foam needs to fill more volume.

Set `TOUCH_DELTA_ON` to about half your *weakest* real touch, and
`TOUCH_DELTA_OFF` to about a quarter.

Expect the numbers to change substantially once the electrode is inside actual
TPU rather than open air. That is the point of the test rig.

## Notes

- `F13` is chosen because no ordinary keyboard has one, so nothing can collide
  with it. If a CircuitPython build lacks `Keycode.F13` the firmware falls back
  to `F12` and says so on the console — update `host/init.lua` to match
- Touch-capable pins are believed to be A0, A6, A7. Unverified against Seeed's
  own documentation; `touchio` will raise on an unsupported pin
