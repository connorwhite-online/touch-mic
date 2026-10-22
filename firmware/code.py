# code.py - soft USB-C dictation button
#
# Board:  Seeed XIAO SAMD21 (hardware capacitive touch + native USB)
# Wiring: one wire from pin A0 to the conductive foam electrode. That is it.
#
# Behaviour: holds the F13 key down for as long as the body is being touched,
# and releases it when you let go. Hammerspoon turns that into Claude's
# dictation (quick touch = start and stay recording, hold = record while held).
#
# Setup: copy this to the CIRCUITPY drive as code.py, and put the
# adafruit_hid folder in CIRCUITPY/lib/.
#
# Open the serial console to watch live numbers while you tune.

import time
import board
import touchio
import usb_hid
from adafruit_hid.keyboard import Keyboard
from adafruit_hid.keycode import Keycode

# ---------------------------------------------------------------- settings

TOUCH_PIN = board.A0      # A0, A6 and A7 are the touch-capable pins

# How far the reading must rise above its resting level to count as a touch.
# These are raw counts, not volts or picofarads. Tune them by watching the
# serial output: touch the body, see how big the jump is, set ON to about
# half that jump and OFF to about a quarter.
TOUCH_DELTA_ON = 120      # rise above baseline that starts a touch
TOUCH_DELTA_OFF = 70      # must fall back below this to end the touch

# The resting level drifts with temperature, humidity and the foam settling.
# This creeps the baseline toward the current reading while untouched, slowly
# enough that it never chases an actual finger.
DRIFT_RATE = 0.01         # 0 = never adapt, 0.1 = adapt fast

SAMPLE_INTERVAL = 0.01    # seconds between readings (100 Hz)
MAX_HOLD = 120.0          # safety: never hold the key longer than this
PRINT_INTERVAL = 0.10     # how often to print telemetry

# ---------------------------------------------------------------- hardware

touch = touchio.TouchIn(TOUCH_PIN)
keyboard = Keyboard(usb_hid.devices)

# F13 is ideal because no normal keyboard has one, so nothing else on the Mac
# can collide with it. If this CircuitPython build lacks it, fall back and say so.
try:
    KEY = Keycode.F13
    KEY_NAME = "F13"
except AttributeError:
    KEY = Keycode.F12
    KEY_NAME = "F12  (F13 not available in this build - update init.lua to match)"

# Establish the resting level from a short burst of samples.
_samples = []
for _ in range(32):
    _samples.append(touch.raw_value)
    time.sleep(0.005)
baseline = sum(_samples) / len(_samples)

print("=" * 52)
print("soft dictation button ready")
print("  key sent:  ", KEY_NAME)
print("  baseline:  ", int(baseline))
print("  thresholds: on +%d / off +%d" % (TOUCH_DELTA_ON, TOUCH_DELTA_OFF))
print("=" * 52)

# ---------------------------------------------------------------- main loop

touching = False
touch_started_at = 0.0
last_print = 0.0
peak_delta = 0

try:
    while True:
        now = time.monotonic()
        raw = touch.raw_value
        delta = raw - baseline

        if not touching:
            # Let the resting level follow slow environmental drift, but only
            # while nothing is touching it.
            baseline += (raw - baseline) * DRIFT_RATE

            if delta > TOUCH_DELTA_ON:
                touching = True
                touch_started_at = now
                peak_delta = delta
                keyboard.press(KEY)
                print("TOUCH   delta=%d" % delta)
        else:
            if delta > peak_delta:
                peak_delta = delta

            # Two separate thresholds (hysteresis) stop the signal chattering
            # on and off when it hovers right at the trigger point.
            if delta < TOUCH_DELTA_OFF:
                touching = False
                keyboard.release(KEY)
                print("RELEASE peak=%d  held=%.2fs" % (peak_delta, now - touch_started_at))
            elif now - touch_started_at > MAX_HOLD:
                touching = False
                keyboard.release(KEY)
                print("RELEASE (safety timeout)")

        if now - last_print >= PRINT_INTERVAL:
            last_print = now
            bar = "#" * min(40, max(0, int(delta / 10)))
            print("raw=%5d base=%5d delta=%+5d %s" % (raw, int(baseline), delta, bar))

        time.sleep(SAMPLE_INTERVAL)

finally:
    # Never leave the key stuck down if this program stops for any reason.
    keyboard.release_all()
