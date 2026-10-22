-- Hardware dictation button -> Claude's own dictation.
--
-- Presses whichever dictation control exists in the view you are ALREADY
-- looking at. It never activates Claude and never switches tabs, so it can't
-- yank you into some other conversation.
--
-- Controls it knows about (discovered by walking Claude's accessibility tree):
--   Code tab   idle:      AXCheckBox "Press and hold to record"
--   Code tab   recording: AXCheckBox "Stop dictation"
--   Chat tab   idle:      AXButton   "Dictate"
--   Chat tab   recording: AXButton   "Finish dictation"  (and "Cancel dictation")
--
-- Gestures, both on the same key:
--   Quick tap (< 0.35s)  -> starts recording and leaves it running; tap again to stop
--   Press and hold       -> records while held, stops on release
--
-- Bindings:
--   F13             <- what the USB-C hardware button sends
--   Ctrl+Alt+Cmd+D  <- same, pressable by hand for testing
--   Ctrl+Alt+Cmd+X  <- cancel/discard the current dictation
--
-- Requires Hammerspoon granted Accessibility.

require("hs.ipc")

local APP = "Claude"
local MAX_DEPTH = 50
local TAP_THRESHOLD = 0.35   -- seconds; below this a press counts as a tap

local IDLE = {
  ["Press and hold to record"] = true,   -- Code tab
  ["Dictate"]                  = true,   -- Chat tab
}
local RECORDING = {
  ["Stop dictation"]   = true,   -- Code tab
  ["Finish dictation"] = true,   -- Chat tab
}
local CANCEL = {
  ["Cancel dictation"] = true,
}

local function appAX()
  local app = hs.application.get(APP)
  if not app then return nil, "Claude is not running" end
  local ax = hs.axuielement.applicationElement(app)
  if not ax then return nil, "no AX element for Claude" end
  -- Electron builds its accessibility tree only when an assistive client asks.
  pcall(function() ax:setAttributeValue("AXManualAccessibility", true) end)
  return ax
end

-- Depth-first search, skipping the menu bar (big subtree, never relevant here).
local function findIn(ax, set)
  local hit
  local function walk(el, d)
    if hit or d > MAX_DEPTH then return end
    local ok, kids = pcall(function() return el:attributeValue("AXChildren") end)
    if not ok or not kids then return end
    for _, c in ipairs(kids) do
      if hit then return end
      local role = tostring(c:attributeValue("AXRole") or "")
      if role ~= "AXMenuBar" and role ~= "AXMenu" then
        local desc = tostring(c:attributeValue("AXDescription") or "")
        if set[desc] then hit = c; return end
        walk(c, d + 1)
      end
    end
  end
  walk(ax, 0)
  return hit
end

-- Returns element, "recording" | "idle" | nil
local function findControl()
  local ax, err = appAX()
  if not ax then return nil, nil, err end
  local rec = findIn(ax, RECORDING)
  if rec then return rec, "recording" end
  local idle = findIn(ax, IDLE)
  if idle then return idle, "idle" end
  return nil, nil, "no dictation control in the current view"
end

function startDictation()
  local el, state, err = findControl()
  if not el then hs.alert.show("Dictation: " .. tostring(err)); return false end
  if state == "recording" then return true end
  el:performAction("AXPress")
  return true
end

function stopDictation()
  local el, state = findControl()
  if el and state == "recording" then el:performAction("AXPress"); return true end
  return false
end

function cancelDictation()
  local ax = appAX()
  if not ax then return false end
  local c = findIn(ax, CANCEL)
  if c then c:performAction("AXPress"); return true end
  return stopDictation()
end

function toggleDictation()
  local el, state, err = findControl()
  if not el then hs.alert.show("Dictation: " .. tostring(err)); return end
  el:performAction("AXPress")
end

-- Tap vs hold, resolved on release.
local pressAt, startedThisPress = 0, false

local function onPress()
  pressAt = hs.timer.secondsSinceEpoch()
  local el, state, err = findControl()
  if not el then
    startedThisPress = false
    hs.alert.show("Dictation: " .. tostring(err))
    return
  end
  if state == "recording" then
    el:performAction("AXPress")   -- tapping while live = stop
    startedThisPress = false
  else
    el:performAction("AXPress")   -- begin
    startedThisPress = true
  end
end

local function onRelease()
  if not startedThisPress then return end
  startedThisPress = false
  if hs.timer.secondsSinceEpoch() - pressAt < TAP_THRESHOLD then
    return                        -- a tap: leave it recording
  end
  stopDictation()                 -- a hold: end on release
end

hs.hotkey.bind({}, "F13", onPress, onRelease)
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "D", onPress, onRelease)
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "X", cancelDictation)

-- Diagnostics:  hs -c 'dictateProbe()'
function dictateProbe()
  local el, state, err = findControl()
  if not el then return "NOT FOUND: " .. tostring(err) end
  return string.format("state=%s desc=%q enabled=%s actions=%s",
    state,
    tostring(el:attributeValue("AXDescription")),
    tostring(el:attributeValue("AXEnabled")),
    table.concat(el:actionNames(), ","))
end

hs.alert.show("Dictation ready - tap or hold F13 / Ctrl+Alt+Cmd+D")
