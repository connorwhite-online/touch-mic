-- touch-mic — hardware button to Claude's own dictation.
--
-- Presses whichever dictation control is in the pane you are actually typing
-- in. Never activates Claude, never switches tabs.
--
-- Controls differ per tab AND change label while recording:
--   Code tab  idle  AXCheckBox "Press and hold to record"
--             live  AXCheckBox "Stop dictation"
--   Chat tab  idle  AXButton   "Dictate"
--             live  AXButton   "Finish dictation" / "Cancel dictation"
--   Send      Code: AXButton "Send"   Chat: AXButton "Send message"
--             (absent while the composer is empty — it appears with the text)
--
-- Gestures:
--   hold and release  -> records while held, then SENDS
--   quick tap         -> starts and stays recording; tap again to stop and
--                        leave the text in the composer to review
--
-- Bindings: F13 (hardware), Ctrl+Alt+Cmd+D (by hand), Ctrl+Alt+Cmd+X (cancel).

require("hs.ipc")

local APP = "Claude"
local MAX_DEPTH = 50
local TAP_THRESHOLD = 0.35
local AUTO_SEND_ON_HOLD = true
local PANE_MARGIN = 30       -- px slack when testing "is focus inside this?"

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

local function frameOf(el)
    local ok, f = pcall(function() return el:attributeValue("AXFrame") end)
    if ok and f and f.w and f.h then return f end
    return nil
end

local function centreOf(el)
    local f = frameOf(el)
    if not f then return nil end
    return { x = f.x + f.w / 2, y = f.y + f.h / 2 }
end

local function contains(f, p, m)
    return p.x >= f.x - m and p.x <= f.x + f.w + m
       and p.y >= f.y - m and p.y <= f.y + f.h + m
end

-- Search for an exact AXDescription, pruning any subtree whose frame does not
-- contain the focus point.
--
-- The pruning does two jobs at once. It picks the right PANE: with a project
-- chat on the left and a thread on the right there are two composers, and a
-- plain tree walk always returns whichever comes first in tree order. And it
-- keeps the search FAST: Claude's tree is large enough that an unpruned walk
-- takes long enough to look like a hang.
--
-- A candidate is tested before its frame is, so a control whose own frame
-- excludes the focus point is still found — only descent is pruned.
local NODE_BUDGET = 1500     -- hard ceiling so a search can never hang

local function findNear(root, set, ref, maxDepth)
    local hit, seen = nil, 0
    local function walk(el, d)
        if hit or d > (maxDepth or MAX_DEPTH) or seen > NODE_BUDGET then return end
        local ok, kids = pcall(function() return el:attributeValue("AXChildren") end)
        if not ok or not kids then return end
        for _, c in ipairs(kids) do
            if hit or seen > NODE_BUDGET then return end
            seen = seen + 1
            local role = tostring(c:attributeValue("AXRole") or "")
            if role ~= "AXMenuBar" and role ~= "AXMenu" then
                if set[tostring(c:attributeValue("AXDescription") or "")] then
                    hit = c
                    return
                end
                local f = ref and frameOf(c)
                if (not ref) or (not f) or contains(f, ref, PANE_MARGIN) then
                    walk(c, d + 1)
                end
            end
        end
    end
    walk(root, 0)
    return hit
end

local function focusRef(ax)
    local ok, f = pcall(function() return ax:attributeValue("AXFocusedUIElement") end)
    if not ok or not f then return nil, nil end
    return centreOf(f), f
end

-- Climb from the focused element and search a SMALL subtree at each level.
--
-- Never search from the application root. Claude's tree grows with the
-- conversation, and in a long session the transcript alone is thousands of
-- elements -- a root walk that was instant early on takes long enough later
-- to look like a hang. Climbing parents costs nothing; it is descending that
-- is expensive, so descend only from near the composer.
local function climbFind(fel, set)
    if not fel then return nil, nil end
    local el = fel
    for i = 1, 9 do
        local okp, p = pcall(function() return el:attributeValue("AXParent") end)
        if not okp or not p then return nil, nil end
        el = p
        local hit = findNear(el, set, nil, 6)
        if hit then return hit, el end
    end
    return nil, nil
end

-- Returns element, state, err, ref, focusedElement
local function findControl()
    local ax, err = appAX()
    if not ax then return nil, nil, err end
    local ref, fel = focusRef(ax)
    local rec = climbFind(fel, RECORDING)
    if rec then return rec, "recording", nil, ref, fel end
    local idle = climbFind(fel, IDLE)
    if idle then return idle, "idle", nil, ref, fel end
    return nil, nil, "no dictation control near the focused composer", ref, fel
end

-- A transcript worth sending. A silent recording comes back as a single
-- character, and "not empty" happily sends that as a message.
local function hasWords(t)
    return #t >= 3 and t:find("%w") ~= nil
end

-- Wait for Claude to finish, THEN send.
--
-- Two phases. First wait for the dictation control to flip back to its idle
-- label -- that is Claude's own "finalised" signal, so no latency constant
-- has to be guessed, and it cannot fire during a pause mid-stream the way
-- text-stability alone can. Then wait for the text to stop changing, to catch
-- any trailing insert. Only then look for the send button, which does not
-- exist until there is text to send.
local function autoSubmit(ref, fel, ctl)
    local phase, tries, last, stable = "finalising", 0, nil, 0
    local timer
    timer = hs.timer.doEvery(0.15, function()
        tries = tries + 1
        if tries > 80 then timer:stop(); return end   -- 12s ceiling

        if phase == "finalising" then
            local done = false
            -- Cheap path: re-read the label on the control we pressed.
            if ctl then
                local ok, d = pcall(function() return ctl:attributeValue("AXDescription") end)
                if ok and d and IDLE[tostring(d)] then done = true end
                if not ok then ctl = nil end   -- element went stale
            end
            -- Fallback, only occasionally: a fresh search is far dearer than
            -- one attribute read, so do not run it every tick.
            if not done and not ctl and tries % 4 == 0 then
                if select(1, climbFind(fel, IDLE)) then done = true end
            end
            if done then phase = "settling" end
            return
        end

        local txt = ""
        if fel then
            local ok, v = pcall(function() return fel:attributeValue("AXValue") end)
            if ok and v then txt = tostring(v) end
        end
        if txt ~= "" and txt == last then stable = stable + 1 else stable = 0 end
        last = txt
        if stable >= 2 then
            timer:stop()
            if hasWords(txt) then
                local btn = select(1, climbFind(fel, SEND))
                if btn then
                    btn:performAction("AXPress")
                elseif hs.application.frontmostApplication():name() == APP then
                    hs.eventtap.keyStroke({}, "return", 0)
                end
            end
        end
    end)
end

-- Returns the control it pressed, so the caller can watch that element flip
-- back to idle rather than searching the tree again.
function stopDictation()
    local el, state = findControl()
    if el and state == "recording" then el:performAction("AXPress"); return el end
    return nil
end

function cancelDictation()
    local ax = appAX()
    if not ax then return false end
    local _, fel = focusRef(ax)
    local c = select(1, climbFind(fel, CANCEL))
    if c then c:performAction("AXPress"); return true end
    return stopDictation()
end

-- Tap vs hold, resolved on release.
local pressAt, startedThisPress, pressRef, pressFel = 0, false, nil, nil

local function onPress()
    pressAt = hs.timer.secondsSinceEpoch()
    local el, state, err, ref, fel = findControl()
    pressRef, pressFel = ref, fel
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
        return   -- a tap: leave it recording, and leave the text to review
    end
    local ctl = stopDictation()
    if AUTO_SEND_ON_HOLD then autoSubmit(pressRef, pressFel, ctl) end
end

hs.hotkey.bind({}, "F13", onPress, onRelease)
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "D", onPress, onRelease)
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "X", cancelDictation)

-- Diagnostics:  hs -c 'dictateProbe()'
-- No send lookup: that button only exists once there is text.
function dictateProbe()
    local el, state, err, ref = findControl()
    if not el then return "NOT FOUND: " .. tostring(err) end
    return string.format("state=%s desc=%q focus=%s",
        state, tostring(el:attributeValue("AXDescription")),
        ref and "tracked" or "none")
end

hs.alert.show("touch-mic ready — hold to talk and send, tap to review")
