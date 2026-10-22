# Host side — pressing Claude's dictation control

[`init.lua`](init.lua) is a Hammerspoon config that finds Claude Desktop's
dictation control in the macOS accessibility tree and presses it. It is what
turns `F13` from the device into Claude listening.

## Install

1. `brew install --cask hammerspoon`
2. Copy `init.lua` to `~/.hammerspoon/init.lua`
3. Launch Hammerspoon and grant it Accessibility (System Settings → Privacy &
   Security → Accessibility)
4. **Restart Hammerspoon.** macOS caches the trust state; `hs.accessibilityState()`
   keeps returning `false` until the app restarts, and `hs.axuielement` fails
   with a permission error even though the grant is already in place
5. Enable "Launch Hammerspoon at login", or the button goes dead after a reboot

Verify with `hs -c 'dictateProbe()'`. Expect something like:

```
state=idle desc="Press and hold to record" enabled=true actions=AXPress,...
```

## Bindings

| Key | Action |
|---|---|
| `F13` | What the device sends. Tap = start and stay recording; hold = record while held |
| `Ctrl+Alt+Cmd+D` | Same, pressable by hand for testing |
| `Ctrl+Alt+Cmd+X` | Cancel and discard the current dictation |

## The controls it presses

These differ per tab **and change their label while recording** — which is the
single most important fact here.

| View | Idle | Recording |
|---|---|---|
| Code tab | `AXCheckBox` `"Press and hold to record"` | `AXCheckBox` `"Stop dictation"` |
| Chat tab | `AXButton` `"Dictate"` | `AXButton` `"Finish dictation"` / `"Cancel dictation"` |

## Three traps, each of which cost real time

**1. Electron builds no accessibility tree until asked.** Before setting
`AXManualAccessibility` on the application element, Claude's entire window reads
as five nested anonymous `AXGroup`s and three unlabelled buttons — the traffic
lights. There is no `AXWebArea` and nothing to find. The switch must also be
re-applied after a tab switch, because the new view is a different renderer.

**2. Subtrees build lazily, and the control is ~28 levels deep.** Walkers capped
at 16 or 26 levels returned "not found" twice and looked like a definitive
negative result. It was not. `MAX_DEPTH` is 50 for this reason.

**3. Never `activate()` the app or switch tabs.** An earlier version did both,
and the effect was to drag the user out of whatever they were working on and
into whichever conversation the Claude tab happened to be showing. Search the
current view only; if there is no dictation control there, say so rather than
going to find one somewhere else.

A fourth, subtler one: the idle and recording labels differ, so a toggle
implemented as "find the idle control and press it twice" starts dictation and
then cannot stop it. `findControl()` checks for the recording labels first.

## When it breaks

Claude's accessibility labels are not a published API. If dictation stops
responding after a Claude update, run `hs -c 'dictateProbe()'` first. If it
reports NOT FOUND, the labels changed — walk the tree and update the `IDLE`,
`RECORDING` and `CANCEL` tables at the top of `init.lua`.

## `set-claude-dictation-shortcut.sh`

Kept for the record only. It writes Claude's `dictationShortcut` config key,
which **does not work** — see [`docs/DECISIONS.md`](../docs/DECISIONS.md). Use
it with `--revert` to clear the key if it was ever set.
