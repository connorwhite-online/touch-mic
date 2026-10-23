-- touch-mic — hardware button to Claude's own dictation.
--
-- Presses whichever dictation control is in the view you are ALREADY in. It
-- never activates Claude and never switches tabs.
--
-- Controls differ per tab AND change label while recording:
--   Code tab  idle  AXCheckBox "Press and hold to record"
--             live  AXCheckBox "Stop dictation"
--   Chat tab  idle  AXButton   "Dictate"
--             live  AXButton   "Finish dictation" / "Cancel dictation"
--   Send      Code: AXButton "Send"   Chat: AXButton "Send message"
--
-- Gestures:
--   hold and release  -> records while held, then SENDS automatically
--   quick tap         -> starts and stays recording; tap again to stop,
--                        text is left in the composer for you to review
--
-- Bindings: F13 (the hardware button), Ctrl+Alt+Cmd+D (by hand),
--           Ctrl+Alt+Cmd+X (cancel and discard).

require("hs.ipc")

local APP = "Claude"
local MAX_DEPTH = 50
local TAP_THRESHOLD = 0.35   -- under this, a press counts as a tap
local AUTO_SEND_ON_HOLD = true

local IDLE = {
    ["Press and hold to record"] = true,
    ["Dictate"]                  = true,
}
local RECORDING = {
    ["Stop dictation"]   = true,
    ["Finish dictation"] = true,
}
local CANCEL = { ["Cancel dictation"] = true }
-- Exact match, so "Send feedback" is never mistaken for the send button.
local SEND = { ["Send"] = true, ["Send message"] = true }

local function appAX()
    local app = hs.application.get(APP)
    if not app then return nil, "Claude is not running" end
    local ax = hs.axuielement.applicationElement(app)
    if not ax then return nil, "no AX element for Claude" end
    -- Electron builds no accessibility tree until an assistive client asks.
    pcall(function() ax:setAttributeValue("AXManualAccessibility", true) end)
    return ax
end

-- Depth-first, skipping the menu bar. `set` is a table of exact AXDescriptions.
local function findIn(root, set, maxDepth)
    local hit
    local function walk(el, d)
        if hit or d > (maxDepth or MAX_DEPTH) then return end
        local ok, kids = pcall(function() return el:attributeValue("AXChildren") end)
        if not ok or not kids then return end
        for _, c in ipairs(kids) do
            if hit then return end
            local role = tostring(c:attributeValue("AXRole") or "")
            if role ~= "AXMenuBar" and role ~= "AXMenu" then
                if set[tostring(c:attributeValue("AXDescription") or "")] then
                    hit = c; return
                end
                walk(c, d + 1)
            end
        end
    end
    walk(root, 0)
    return hit
end

local function findRole(root, role, maxDepth)
    local hit
    local function walk(el, d)
        if hit or d > (maxDepth or 14) then return end
        local ok, kids = pcall(function() return el:attributeValue("AXChildren") end)
        if not ok or not kids then return end
        for _, c in ipairs(kids) do
            if hit then return end
            if tostring(c:attributeValue("AXRole") or "") == role then hit = c; return end
            walk(c, d + 1)
        end
    end
    walk(root, 0)
    return hit
end

-- Which pane are we actually in? With a project chat on the left and a thread
-- on the right there are TWO composers, and a plain tree walk always returns
-- whichever comes first in tree order — so dictation lands in the wrong one.
-- Start from keyboard focus and climb until an ancestor contains a dictation
-- control; that ancestor is the pane the user is typing in.
local function focusScope(ax)
    local ok, f = pcall(function() return ax:attributeValue("AXFocusedUIElement") end)
    if not ok or not f then return nil end
    local el = f
    for _ = 1, 8 do
        local okp, p = pcall(function() return el:attributeValue("AXParent") end)
        if not okp or not p then return nil end
        el = p
        if findIn(el, RECORDING, 8) or findIn(el, IDLE, 8) then return el end
    end
    return nil
end

-- Returns element, state, err, scope
local function findControl()
    local ax, err = appAX()
    if not ax then return nil, nil, err end
    local scope = focusScope(ax)
    local depth = scope and 10 or MAX_DEPTH
    scope = scope or ax
    local rec = findIn(scope, RECORDING, depth)
    if rec then return rec, "recording", nil, scope end
    local idle = findIn(scope, IDLE, depth)
    if idle then return idle, "idle", nil, scope end
    return nil, nil, "no dictation control in the current view", scope
end

-- Wait for the transcript to settle, then press Send. Polling the composer
-- beats a fixed delay because transcription latency varies a lot; a fixed
-- wait either sends a half-finished sentence or feels sluggish.
local function autoSubmit(scope)
    if not scope then return end
    local last, stable, tries = nil, 0, 0
    local timer
    timer = hs.timer.doEvery(0.15, function()
        tries = tries + 1
        local ta = findRole(scope, "AXTextArea", 12)
        local txt = ta and tostring(ta:attributeValue("AXValue") or "") or ""
        if txt ~= "" and txt == last then stable = stable + 1 else stable = 0 end
        last = txt
        if (stable >= 2 and txt ~= "") or tries > 34 then
            timer:stop()
            if txt ~= "" then
                local btn = findIn(scope, SEND, 12)
                if btn then btn:performAction("AXPress") end
            end
        end
    end)
end

function startDictation()
    local el, state, err = findControl()
    if not el then hs.alert.show("Dictation: " .. tostring(err)); return false end
    if state ~= "recording" then el:performAction("AXPress") end
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
    local c = findIn(ax, CANCEL, MAX_DEPTH)
    if c then c:performAction("AXPress"); return true end
    return stopDictation()
end

-- Tap vs hold, resolved on release.
local pressAt, startedThisPress, pressScope = 0, false, nil

local function onPress()
    pressAt = hs.timer.secondsSinceEpoch()
    local el, state, err, scope = findControl()
    pressScope = scope
    if not el then
        startedThisPress = false
        hs.alert.show("Dictation: " .. tostring(err))
        return
    end
    el:performAction("AXPress")
    startedThisPress = (state ~= "recording")
end

local function onRelease()
    if not startedThisPress then return end
    startedThisPress = false
    if hs.timer.secondsSinceEpoch() - pressAt < TAP_THRESHOLD then
        return   -- a tap: leave it recording, and leave the text for review
    end
    stopDictation()
    if AUTO_SEND_ON_HOLD then autoSubmit(pressScope) end
end

hs.hotkey.bind({}, "F13", onPress, onRelease)
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "D", onPress, onRelease)
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "X", cancelDictation)

-- Diagnostics:  hs -c 'dictateProbe()'
function dictateProbe()
    local el, state, err, scope = findControl()
    local ax = appAX()
    local scoped = (scope and ax and scope ~= ax) and "focused pane" or "whole app"
    if not el then return "NOT FOUND (" .. scoped .. "): " .. tostring(err) end
    local send = findIn(scope, SEND, 12)
    return string.format("state=%s desc=%q scope=%s send=%s",
        state, tostring(el:attributeValue("AXDescription")), scoped,
        send and tostring(send:attributeValue("AXDescription")) or "none")
end

hs.alert.show("touch-mic ready — hold to talk and send, tap to review")
