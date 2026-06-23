-- Window tiling via hs.window (see https://www.hammerspoon.org/go/#winresize).
-- Restore and space switching stay on Raycast deep links.
-- Left/right/top/bottom half keys cycle: 50% -> 33% -> 67% (same key, same window), Raycast-style.

local M = {}

local ctx = nil
-- Pixels to reserve at top/bottom of hs.screen:frame() for HUD bars (set from constants in init).
local insetTopPx = 0
local insetBottomPx = 0
local insetLeftPx = 0
local insetRightPx = 0

-- { winId = number, edge = string, step = 0|1|2 }; step indexes the rects below (0-based after advance).
local snapCycle = { winId = nil, edge = nil, step = 0 }

local LEFT_SNAPS = {
  { x = 0, y = 0, w = 0.5,   h = 1 },
  { x = 0, y = 0, w = 1 / 3, h = 1 },
  { x = 0, y = 0, w = 2 / 3, h = 1 },
}

local RIGHT_SNAPS = {
  { x = 0.5,   y = 0, w = 0.5,   h = 1 },
  { x = 2 / 3, y = 0, w = 1 / 3, h = 1 },
  { x = 1 / 3, y = 0, w = 2 / 3, h = 1 },
}

local TOP_SNAPS = {
  { x = 0, y = 0, w = 1, h = 0.5 },
  { x = 0, y = 0, w = 1, h = 1 / 3 },
  { x = 0, y = 0, w = 1, h = 2 / 3 },
}

local BOTTOM_SNAPS = {
  { x = 0, y = 0.5,   w = 1, h = 0.5 },
  { x = 0, y = 2 / 3, w = 1, h = 1 / 3 },
  { x = 0, y = 1 / 3, w = 1, h = 2 / 3 },
}

local LEFT_CORNER_SNAPS = {
  { x = 0, y = 0,   w = 0.5, h = 0.5 },
  { x = 0, y = 0.5, w = 0.5, h = 0.5 },
}

local RIGHT_CORNER_SNAPS = {
  { x = 0.5, y = 0,   w = 0.5, h = 0.5 },
  { x = 0.5, y = 0.5, w = 0.5, h = 0.5 },
}

local function clearSnapCycle()
  snapCycle.winId = nil
  snapCycle.edge = nil
  snapCycle.step = 0
end

--- Usable rect for tiling: screen frame minus HUD strips (unit rects 0–1 map within this).
local function workAreaForWindow(win)
  local f = win:screen():frame()
  return {
    x = f.x + insetLeftPx,
    y = f.y + insetTopPx,
    w = f.w - insetLeftPx - insetRightPx,
    h = f.h - insetTopPx - insetBottomPx,
  }
end

-- Second arg 0 disables transition; avoids moveToUnit so we respect HUD insets.
-- Per-edge gap: full GAP on screen edges, half on shared edges (neighbor contributes the other half → equal gap everywhere).
local GAP = 4
local HALF_GAP = GAP / 2

local function getExpectedFrame(win, unit)
  local wa         = workAreaForWindow(win)
  local leftEdge   = unit.x
  local rightEdge  = unit.x + unit.w
  local topEdge    = unit.y
  local bottomEdge = unit.y + unit.h

  local leftPad    = math.abs(leftEdge) < 0.001 and GAP or HALF_GAP
  local rightPad   = math.abs(rightEdge - 1) < 0.001 and GAP or HALF_GAP
  local topPad     = math.abs(topEdge) < 0.001 and GAP or HALF_GAP
  local bottomPad  = math.abs(bottomEdge - 1) < 0.001 and GAP or HALF_GAP

  return {
    x = wa.x + unit.x * wa.w + leftPad,
    y = wa.y + unit.y * wa.h + topPad,
    w = unit.w * wa.w - leftPad - rightPad - insetLeftPx - insetRightPx,
    h = unit.h * wa.h - topPad - bottomPad - insetTopPx - insetBottomPx,
  }
end

local function tile(win, unit)
  win:setFrame(getExpectedFrame(win, unit), 0)
end

local function findMatchingStep(win, rects)
  local frame = win:frame()
  for i, rect in ipairs(rects) do
    local expected = getExpectedFrame(win, rect)
    if math.abs(frame.x - expected.x) <= 2 and
        math.abs(frame.y - expected.y) <= 2 and
        math.abs(frame.w - expected.w) <= 2 and
        math.abs(frame.h - expected.h) <= 2 then
      return i
    end
  end
  return nil
end

local function withFocused(fn)
  local win = hs.window.focusedWindow()
  if win then
    fn(win)
  end
end

--- Cycle half / third / two-thirds along one edge (same window + same half hotkey repeats).
local function cycleSnaps(win, edge, rects)
  local id = win:id()
  local same = snapCycle.winId == id and snapCycle.edge == edge
  local step

  if same then
    step = (snapCycle.step + 1) % #rects
  else
    local matchIdx = findMatchingStep(win, rects)
    step = matchIdx and (matchIdx % #rects) or 0
  end

  tile(win, rects[step + 1])

  snapCycle.winId = id
  snapCycle.edge = edge
  snapCycle.step = step
end

function HK_almostMaximizeWindow()
  clearSnapCycle()
  withFocused(function(win)
    tile(win, { x = 0.03, y = 0.03, w = 0.94, h = 0.94 })
  end)
end

function HK_bottomHalfWindow()
  withFocused(function(win)
    cycleSnaps(win, "bottom", BOTTOM_SNAPS)
  end)
end

function HK_leftHalfWindow()
  withFocused(function(win)
    cycleSnaps(win, "left", LEFT_SNAPS)
  end)
end

local MAX_STEPS = {
  { x = 0,   y = 0,    w = 1,    h = 1 },
  { x = 0.1, y = 0.06, w = 0.80, h = 0.88 },
  { x = 0.2, y = 0.06, w = 0.60, h = 0.88 },
}

function HK_maximizeWindow()
  withFocused(function(win)
    cycleSnaps(win, "maximize", MAX_STEPS)
  end)
end

function HK_restoreWindow()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/window-management/restore")
  end
end

function HK_rightHalfWindow()
  withFocused(function(win)
    cycleSnaps(win, "right", RIGHT_SNAPS)
  end)
end

function HK_topHalfWindow()
  withFocused(function(win)
    cycleSnaps(win, "top", TOP_SNAPS)
  end)
end

function HK_leftCornerWindow()
  withFocused(function(win)
    cycleSnaps(win, "leftCorner", LEFT_CORNER_SNAPS)
  end)
end

function HK_rightCornerWindow()
  withFocused(function(win)
    cycleSnaps(win, "rightCorner", RIGHT_CORNER_SNAPS)
  end)
end

function HK_nextDesktop()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/window-management/next-desktop")
  end
end

function HK_previousDesktop()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/window-management/previous-desktop")
  end
end

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  insetTopPx = ctx.constants.TILE_HUD_TOP_INSET_PX or 0
  insetBottomPx = ctx.constants.TILE_HUD_BOTTOM_INSET_PX or 0
  insetLeftPx = ctx.constants.TILE_HUD_LEFT_INSET_PX or 0
  insetRightPx = ctx.constants.TILE_HUD_RIGHT_INSET_PX or 0

  -- Instant resizes for any code that omits an explicit duration (default is 0.2).
  hs.window.animationDuration = 0

  ctx.log.console.success("Windows feature initialized")

  return result.ok()
end

return M
