--[[
  Larry pet overlay. Scurry mode (backward sprite + motion):
  - Toggle: HK_toggleLarryPetScurryMode() or G_larryPetSetScurryMode(true|false)
  - OpenClaw can drive clicks visually by writing one line to:
      ~/.openclaw/workspace/.larry-scurry-target
    Lines:
      x,y           screen coords: Larry runs there, faces away, stays until idle or "home"
      home          return Larry to his corner (same as G_larryPetReturnHome())
    After each x,y the file mtime must change (touch, or unique suffix on a second line).
  - Larry does not run home after every click; he stays until ~28s pass with no new x,y
    (tune via G_larryPetSetIdleHomeSeconds), or when you send "home" / G_larryPetReturnHome().
  - With scurry mode ON, before a programmatic click:
      hs -c 'G_larryPetScurryToScreenPoint(400, 300)'
]]

local M = {}

local pet = nil
local bubbleBg = nil
local bubbleText = nil
local bobTimer = nil
local screenWatcher = nil
local bubbleTimer = nil
local baseFrame = nil
local visible = false
local step = 0
local activeMode = false

-- Backward "OpenClaw driver" scurry mode
local scurryMode = false
local signalWatcher = nil
local scurryAnimTimer = nil
local returnHomeTimer = nil
local lastSignalMtime = 0

local SIGNAL_REL = "/.openclaw/workspace/.larry-scurry-target"

-- After the last x,y signal, Larry returns home only if nothing new arrives for this long.
-- Increase if he walks home while OpenClaw is still typing; decrease to sit back sooner.
local scurryIdleHomeSec = 28

local function signalPath()
  return (os.getenv("HOME") or "") .. SIGNAL_REL
end

local function imagePathForwards()
  return hs.configdir .. "/assets/larry-lobster-pet-facing-forwards.png"
end

local function imagePathAway()
  return hs.configdir .. "/assets/larry-lobster-pet-facing-away.png"
end

local function petFrame()
  local screen = hs.screen.mainScreen()
  local frame = screen:fullFrame()
  local size = math.floor(math.min(frame.w, frame.h) * 0.14)
  local marginX = 26
  local marginY = 30

  return {
    x = frame.x + frame.w - size - marginX,
    y = frame.y + frame.h - size - marginY,
    w = size,
    h = size,
  }
end

local function bubbleFrame()
  local pf = petFrame()
  local width = 220
  local height = 52

  return {
    x = pf.x - width + 12,
    y = pf.y - 18,
    w = width,
    h = height,
  }
end

local function screenAtPoint(px, py)
  for _, s in ipairs(hs.screen.allScreens()) do
    local f = s:fullFrame()
    if px >= f.x and px < f.x + f.w and py >= f.y and py < f.y + f.h then
      return s
    end
  end
  return hs.screen.mainScreen()
end

local function stopBubbleTimer()
  if bubbleTimer then
    bubbleTimer:stop()
    bubbleTimer = nil
  end
end

local function stopBobbing()
  if bobTimer then
    bobTimer:stop()
    bobTimer = nil
  end
end

local function stopScurryAnim()
  if scurryAnimTimer then
    scurryAnimTimer:stop()
    scurryAnimTimer = nil
  end
end

local function stopReturnHomeTimer()
  if returnHomeTimer then
    returnHomeTimer:stop()
    returnHomeTimer = nil
  end
end

local function stopSignalWatcher()
  if signalWatcher then
    signalWatcher:stop()
    signalWatcher = nil
  end
  lastSignalMtime = 0
end

local function hideBubble()
  stopBubbleTimer()
  if bubbleBg then bubbleBg:hide() end
  if bubbleText then bubbleText:hide() end
  activeMode = false
end

local function applyPetSprite(mode)
  if not pet then
    return
  end

  local path
  if mode == "away" then
    path = imagePathAway()
  else
    path = imagePathForwards()
  end

  if not hs.fs.attributes(path) then
    return
  end
  local img = hs.image.imageFromPath(path)
  if not img then
    return
  end
  local ok = pcall(function()
    pet:setImage(img)
  end)
  if not ok then
    pet:setFrame(baseFrame or petFrame())
  end
end

local function ensureBubble()
  if bubbleBg and bubbleText then
    return true
  end

  local frame = bubbleFrame()

  bubbleBg = hs.drawing.rectangle(frame)
  bubbleBg:setRoundedRectRadii(18, 18)
  bubbleBg:setFill(true)
  bubbleBg:setStroke(false)
  bubbleBg:setFillColor({ red = 0.07, green = 0.09, blue = 0.14, alpha = 0.90 })
  bubbleBg:setLevel("floating")
  bubbleBg:setBehaviorByLabels({ "canJoinAllSpaces", "stationary", "ignoresCycle", "fullScreenAuxiliary" })

  bubbleText = hs.drawing.text({ x = frame.x + 16, y = frame.y + 10, w = frame.w - 32, h = frame.h - 18 },
  "Larry is driving")
  bubbleText:setTextSize(19)
  bubbleText:setTextColor({ white = 1, alpha = 0.98 })
  bubbleText:setLevel("floating")
  bubbleText:setBehaviorByLabels({ "canJoinAllSpaces", "stationary", "ignoresCycle", "fullScreenAuxiliary" })

  bubbleBg:hide()
  bubbleText:hide()
  return true
end

local function showBubble(message, seconds)
  ensureBubble()
  stopBubbleTimer()

  local frame = bubbleFrame()
  bubbleBg:setFrame(frame)
  bubbleText:setFrame({ x = frame.x + 16, y = frame.y + 10, w = frame.w - 32, h = frame.h - 18 })
  bubbleText:setText(message or "Larry is driving")

  bubbleBg:show()
  bubbleText:show()

  if seconds and seconds > 0 then
    bubbleTimer = hs.timer.doAfter(seconds, function()
      hideBubble()
    end)
  end
end

---@param dest { x: number, y: number, w: number, h: number }
---@param opts { steps?: number, jitter?: number, onDone?: function }
local function tweenBaseFrameTo(dest, opts)
  opts = opts or {}
  local steps = opts.steps or 16
  local jitter = opts.jitter or 7
  local onDone = opts.onDone

  stopScurryAnim()
  if not pet or not visible or not baseFrame then
    if onDone then onDone() end
    return
  end

  local sx, sy, sw, sh = baseFrame.x, baseFrame.y, baseFrame.w, baseFrame.h
  local dx, dy = dest.x, dest.y
  local frameStep = 0

  scurryAnimTimer = hs.timer.doEvery(0.03, function()
    if not pet or not visible or not baseFrame then
      stopScurryAnim()
      if onDone then onDone() end
      return
    end

    frameStep = frameStep + 1
    local t = math.min(1, frameStep / steps)
    local te = 1 - (1 - t) * (1 - t) * (1 - t)
    local jx = jitter > 0 and (math.random() - 0.5) * 2 * jitter * (1 - t) or 0
    local jy = jitter > 0 and (math.random() - 0.5) * 2 * jitter * (1 - t) or 0

    baseFrame = {
      x = sx + (dx - sx) * te + jx,
      y = sy + (dy - sy) * te + jy,
      w = sw,
      h = sh,
    }
    pet:setFrame(baseFrame)

    if t >= 1 then
      stopScurryAnim()
      baseFrame = { x = dx, y = dy, w = sw, h = sh }
      pet:setFrame(baseFrame)
      if onDone then onDone() end
    end
  end)
end

local function tweenReturnHome(onDone)
  if not visible or not pet then
    if onDone then onDone() end
    return
  end
  local home = petFrame()
  tweenBaseFrameTo(home, {
    steps = 18,
    jitter = 5,
    onDone = function()
      applyPetSprite("forwards")
      if onDone then onDone() end
    end,
  })
end

--- Debounced: resets on each new scurry target so Larry stays put during multi-step automation.
local function scheduleIdleReturnHome()
  stopReturnHomeTimer()
  returnHomeTimer = hs.timer.doAfter(scurryIdleHomeSec, function()
    returnHomeTimer = nil
    tweenReturnHome()
  end)
end

function G_larryPetScurryToScreenPoint(clickX, clickY)
  if not scurryMode then
    return false
  end

  if not pet or not visible or not baseFrame then
    local _, err = ensurePet()
    if err then
      return false
    end
  end

  local x = tonumber(clickX)
  local y = tonumber(clickY)
  if not x or not y then
    return false
  end

  stopReturnHomeTimer()
  stopBobbing()
  applyPetSprite("away")

  local scr = screenAtPoint(x, y)
  local sf = scr:fullFrame()
  local w, h = baseFrame.w, baseFrame.h
  local margin = 6

  local destX = x - w / 2
  local destY = y - h - 10

  destX = math.max(sf.x + margin, math.min(destX, sf.x + sf.w - w - margin))
  destY = math.max(sf.y + margin, math.min(destY, sf.y + sf.h - h - margin))

  tweenBaseFrameTo({ x = destX, y = destY, w = w, h = h }, {
    steps = 18,
    jitter = scurryMode and 9 or 5,
    onDone = function()
      if visible then
        scheduleIdleReturnHome()
      end
      startBobbing()
    end,
  })

  return true
end

--- End of automation batch: Larry walks back to the corner (faces you again).
function G_larryPetReturnHome()
  if not pet or not visible or not baseFrame then
    local _, err = ensurePet()
    if err then
      return false
    end
  end
  stopReturnHomeTimer()
  stopBobbing()
  tweenReturnHome(function()
    startBobbing()
  end)
  return true
end

local function tryConsumeSignalFile()
  if not scurryMode then
    return
  end

  local path = signalPath()
  local attr = hs.fs.attributes(path)
  if not attr then
    return
  end
  local mt = attr.modification
  if type(mt) ~= "number" then
    return
  end
  if mt <= lastSignalMtime then
    return
  end

  local f = io.open(path, "r")
  if not f then
    return
  end
  local line = f:read("*l")
  f:close()

  lastSignalMtime = mt

  if not line then
    return
  end
  if line:match("^%s*home%s*$") then
    G_larryPetReturnHome()
    return
  end
  local sx, sy = line:match("^%s*(-?%d+)%s*,%s*(-?%d+)%s*$")
  if sx and sy then
    G_larryPetScurryToScreenPoint(tonumber(sx), tonumber(sy))
  end
end

local function startSignalWatcher()
  stopSignalWatcher()
  local dir = (os.getenv("HOME") or "") .. "/.openclaw/workspace"
  if not hs.fs.attributes(dir) then
    return
  end

  local ok, watcherOrErr = pcall(function()
    return hs.pathwatcher.new(dir, function()
      tryConsumeSignalFile()
    end)
  end)

  if ok and watcherOrErr then
    signalWatcher = watcherOrErr
    signalWatcher:start()
    tryConsumeSignalFile()
  end
end

local function startBobbing()
  stopBobbing()
  bobTimer = hs.timer.doEvery(0.08, function()
    if not pet or not visible or not baseFrame then
      return
    end
    if scurryAnimTimer then
      return
    end

    step = step + 0.28
    local amplitude = activeMode and 8 or 5
    pet:setFrame({
      x = baseFrame.x,
      y = baseFrame.y + math.sin(step) * amplitude,
      w = baseFrame.w,
      h = baseFrame.h,
    })
  end)
end

local function ensurePet()
  if pet then
    return pet
  end

  local path = imagePathForwards()
  if not hs.fs.attributes(path) then
    return nil, "Missing pet asset: " .. path
  end

  baseFrame = petFrame()
  pet = hs.drawing.image(baseFrame, path)
  if not pet then
    return nil, "Failed to create Larry pet drawing"
  end

  pet:setLevel("floating")
  pet:setBehaviorByLabels({ "canJoinAllSpaces", "stationary", "ignoresCycle", "fullScreenAuxiliary" })
  pet:show()
  visible = true
  ensureBubble()
  applyPetSprite("forwards")
  startBobbing()

  return pet
end

local function repositionPet()
  if not pet then
    return
  end

  baseFrame = petFrame()
  pet:setFrame(baseFrame)

  if bubbleBg and bubbleText then
    local frame = bubbleFrame()
    bubbleBg:setFrame(frame)
    bubbleText:setFrame({ x = frame.x + 16, y = frame.y + 10, w = frame.w - 32, h = frame.h - 18 })
  end
end

function G_showLarryPet()
  local _, err = ensurePet()
  if err then
    hs.alert.show(err, 2)
    return false
  end

  visible = true
  repositionPet()
  pet:show()
  applyPetSprite("forwards")
  startBobbing()
  return true
end

function G_hideLarryPet()
  visible = false
  activeMode = false
  scurryMode = false
  stopBobbing()
  stopScurryAnim()
  stopReturnHomeTimer()
  stopSignalWatcher()
  hideBubble()
  if pet then
    applyPetSprite("forwards")
    pet:hide()
  end
  return true
end

function G_larryPetSay(message, seconds)
  local ok = G_showLarryPet()
  if not ok then return false end
  showBubble(message or "Hey Rio", seconds or 3)
  return true
end

function G_larryPetSetActive(message, seconds)
  local ok = G_showLarryPet()
  if not ok then return false end
  activeMode = true
  showBubble(message or "Larry is driving", seconds or 4)
  startBobbing()
  return true
end

function G_larryPetSetScurryMode(enabled)
  local want = enabled and true or false
  local ok = G_showLarryPet()
  if not ok then
    return false
  end

  scurryMode = want
  applyPetSprite("forwards")

  if scurryMode then
    startSignalWatcher()
    showBubble("Larry remote", 2.5)
  else
    stopSignalWatcher()
    stopReturnHomeTimer()
    stopScurryAnim()
    hideBubble()
    repositionPet()
  end

  startBobbing()
  return true
end

function G_larryPetToggleScurryMode()
  return G_larryPetSetScurryMode(not scurryMode)
end

--- How long to wait after the last x,y before Larry walks back to the corner (1–300 seconds).
function G_larryPetSetIdleHomeSeconds(sec)
  local n = tonumber(sec)
  if not n then
    return false
  end
  scurryIdleHomeSec = math.max(1, math.min(300, n))
  return true
end

function HK_toggleLarryPet()
  if pet and visible then
    return G_hideLarryPet()
  else
    return G_showLarryPet()
  end
end

function HK_toggleLarryPetScurryMode()
  G_larryPetToggleScurryMode()
  return true
end

function M.init(ctx)
  local result = require "core.utils.result"

  stopSignalWatcher()
  if screenWatcher then
    screenWatcher:stop()
  end

  local _, err = ensurePet()
  if err then
    return result.fail("PET_ASSET_MISSING", err, { level = "warn" })
  end

  screenWatcher = hs.screen.watcher.new(function()
    repositionPet()
  end)
  screenWatcher:start()

  hs.timer.doAfter(0.8, function()
    G_larryPetSay("Larry online", 12)
  end)

  if ctx and ctx.log and ctx.log.console then
    ctx.log.console.success("Larry pet overlay loaded")
  end

  return result.ok()
end

return M
