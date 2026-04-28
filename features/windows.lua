-- Window tiling via hs.window (see https://www.hammerspoon.org/go/#winresize).
-- Restore and space switching stay on Raycast deep links.
-- Left/right/top/bottom half keys cycle: 50% -> 33% -> 67% (same key, same window), Raycast-style.

local M = {}

local ctx = nil

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

-- Second arg 0 disables transition; default follows hs.window.animationDuration (often 0.2s).
local function tile(win, unit)
  win:moveToUnit(unit, 0)
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

  -- Instant resizes for any code that omits an explicit duration (default is 0.2).
  hs.window.animationDuration = 0

  ctx.log.console.success("Windows feature initialized")

  return result.ok()
end

return M
