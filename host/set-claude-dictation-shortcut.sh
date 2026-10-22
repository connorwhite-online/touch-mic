#!/bin/bash
# Bind Claude Desktop's in-app dictation to a keyboard shortcut.
#
# WHY A SCRIPT: the `dictationShortcut` setting must be written while Claude is
# NOT running, or the app may rewrite config.json on quit and silently discard
# the change (which would look like "the setting doesn't work").
#
# RUN THIS FROM Terminal.app -- NOT from a terminal inside Claude, because this
# script waits for Claude to quit and would kill its own shell.
#
#   chmod +x set-claude-dictation-shortcut.sh
#   ./set-claude-dictation-shortcut.sh "Control+Alt+Command+D"
#   ./set-claude-dictation-shortcut.sh --revert
#
# Accelerator syntax is Electron's: Command, Control, Alt, Shift, Super,
# CommandOrControl, F1-F24, letters, digits. Examples:
#   "Control+Alt+Command+D"   <- testable by hand, good for proving it works
#   "F13"                     <- what the hardware button should send

set -euo pipefail

CFG="$HOME/Library/Application Support/Claude/config.json"
APP="/Applications/Claude.app"
MAIN="$APP/Contents/MacOS/Claude"
ACCEL="${1:-Control+Alt+Command+D}"

[ -f "$CFG" ] || { echo "No config.json at $CFG"; exit 1; }

backup="$CFG.bak.$(date +%Y%m%d-%H%M%S)"
cp "$CFG" "$backup"
echo "Backed up -> $backup"

if [ "$ACCEL" = "--revert" ]; then
  python3 -I - "$CFG" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
removed = [k for k in ("dictationShortcut", "quickEntryDictationShortcut") if d.pop(k, None) is not None]
json.dump(d, open(p, "w"), indent=2)
print("Removed:", ", ".join(removed) if removed else "nothing was set")
PY
  echo "Reverted to defaults. Relaunch Claude."
  exit 0
fi

# Wait for Claude to exit so the app can't clobber our write.
if pgrep -f "$MAIN" >/dev/null 2>&1; then
  echo
  echo "Claude is running. Quit it now (Cmd+Q). Waiting..."
  while pgrep -f "$MAIN" >/dev/null 2>&1; do sleep 1; done
  sleep 2   # let the final config flush settle
fi
echo "Claude is stopped. Writing setting..."

ACCEL="$ACCEL" python3 -I - "$CFG" <<'PY'
import json, os, sys
p = sys.argv[1]
d = json.load(open(p))
d["dictationShortcut"] = {"accelerator": os.environ["ACCEL"]}
json.dump(d, open(p, "w"), indent=2)
print("Set dictationShortcut =", json.dumps(d["dictationShortcut"]))
PY

echo "Relaunching Claude..."
open -a "$APP"

cat <<EOF

Done. Now test it:

  1. Click into some OTHER app (TextEdit, Notes, anything).
  2. Press: $ACCEL
  3. Watch for Claude's dictation indicator.

What the result tells you:
  - Dictation starts, Claude NOT focused  -> global. This is the win.
  - Starts only when Claude IS focused    -> app-scoped; needs a helper to
                                             focus Claude first, still fine.
  - Nothing at all                        -> the key is gated by the
                                             'dictationEnabled' policy flag,
                                             or this build has no handler
                                             wired to the setting.

Revert any time:
  ./set-claude-dictation-shortcut.sh --revert
EOF
