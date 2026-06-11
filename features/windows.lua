-- Window tiling via hs.window (see https://www.hammerspoon.org/go/#winresize).
-- Restore and space switching stay on Raycast deep links.
-- Left/right/top/bottom half keys cycle: 50% -> 33% -> 67% (same key, same window), Raycast-style.

local M = {}

local ctx = nil
-- Pixels to reserve at top/bottom of hs.screen:frame() for HUD bars (set from constants in init).
local insetTopPx = 0
local insetBottomPx = 0

-- { winId = number, edge = string, step = 0|1|2 }; step indexes the rects below (0-based after advance).
local snapCycle = { winId = nil, edge = nil, step = 0 }

local LEFT_SNAPS = {
  { x = 0, y = 0, w = 0.5, h = 1 },
  { x = 0, y = 0, w = 1 / 3, h = 1 },
  { x = 0, y = 0, w = 2 / 3, h = 1 },
}

local RIGHT_SNAPS = {
  { x = 0.5, y = 0, w = 0.5, h = 1 },
  { x = 2 / 3, y = 0, w = 1 / 3, h = 1 },
  { x = 1 / 3, y = 0, w = 2 / 3, h = 1 },
}

local TOP_SNAPS = {
  { x = 0, y = 0, w = 1, h = 0.5 },
  { x = 0, y = 0, w = 1, h = 1 / 3 },
  { x = 0, y = 0, w = 1, h = 2 / 3 },
}

local BOTTOM_SNAPS = {
  { x = 0, y = 0.5, w = 1, h = 0.5 },
  { x = 0, y = 2 / 3, w = 1, h = 1 / 3 },
  { x = 0, y = 1 / 3, w = 1, h = 2 / 3 },
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
    x = f.x,
    y = f.y + insetTopPx,
    w = f.w,
    h = f.h - insetTopPx - insetBottomPx,
  }
end

-- Second arg 0 disables transition; avoids moveToUnit so we respect HUD insets.
-- Per-edge gap: full GAP on screen edges, half on shared edges (neighbor contributes the other half → equal gap everywhere).
local GAP = 4
local HALF_GAP = GAP / 2

local function tile(win, unit)
  local wa = workAreaForWindow(win)
  local leftEdge   = unit.x
  local rightEdge  = unit.x + unit.w
  local topEdge    = unit.y
  local bottomEdge = unit.y + unit.h

  local leftPad  = math.abs(leftEdge)   < 0.001 and GAP or HALF_GAP
  local rightPad = math.abs(rightEdge  - 1) < 0.001 and GAP or HALF_GAP
  local topPad   = math.abs(topEdge)    < 0.001 and GAP or HALF_GAP
  local bottomPad= math.abs(bottomEdge - 1) < 0.001 and GAP or HALF_GAP

  win:setFrame({
    x = wa.x + unit.x * wa.w + leftPad,
    y = wa.y + unit.y * wa.h + topPad,
    w = unit.w * wa.w - leftPad - rightPad,
    h = unit.h * wa.h - topPad - bottomPad,
  }, 0)
end

local function withFocused(fn)
  local win = hs.window.focusedWindow()
  if win then
    fn(win)
  end
end

--- Cycle half / third / two-thirds along one edge (same window + same half hotkey repeats).
local function cycleEdgeThirds(win, edge, rects)
  local id = win:id()
  local same = snapCycle.winId == id and snapCycle.edge == edge
  local step = same and ((snapCycle.step + 1) % 3) or 0
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
    cycleEdgeThirds(win, "bottom", BOTTOM_SNAPS)
  end)
end

function HK_bottomLeftQuarterWindow()
  clearSnapCycle()
  withFocused(function(win)
    tile(win, { x = 0, y = 0.5, w = 0.5, h = 0.5 })
  end)
end

function HK_bottomRightQuarterWindow()
  clearSnapCycle()
  withFocused(function(win)
    tile(win, { x = 0.5, y = 0.5, w = 0.5, h = 0.5 })
  end)
end

function HK_leftHalfWindow()
  withFocused(function(win)
    cycleEdgeThirds(win, "left", LEFT_SNAPS)
  end)
end

function HK_maximizeWindow()
  clearSnapCycle()
  withFocused(function(win)
    tile(win, { x = 0, y = 0, w = 1, h = 1 })
  end)
end

function HK_restoreWindow()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/window-management/restore")
  end
end

function HK_rightHalfWindow()
  withFocused(function(win)
    cycleEdgeThirds(win, "right", RIGHT_SNAPS)
  end)
end

function HK_topHalfWindow()
  withFocused(function(win)
    cycleEdgeThirds(win, "top", TOP_SNAPS)
  end)
end

function HK_topLeftQuarterWindow()
  clearSnapCycle()
  withFocused(function(win)
    tile(win, { x = 0, y = 0, w = 0.5, h = 0.5 })
  end)
end

function HK_topRightQuarterWindow()
  clearSnapCycle()
  withFocused(function(win)
    tile(win, { x = 0.5, y = 0, w = 0.5, h = 0.5 })
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

  -- Instant resizes for any code that omits an explicit duration (default is 0.2).
  hs.window.animationDuration = 0

  ctx.log.console.success("Windows feature initialized")

  return result.ok()
end

return M
