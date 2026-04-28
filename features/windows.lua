-- Window tiling via hs.window (see https://www.hammerspoon.org/go/#winresize).
-- Restore and space switching stay on Raycast deep links.

local M = {}

local ctx = nil

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

function HK_almostMaximizeWindow()
  withFocused(function(win)
    tile(win, { x = 0.03, y = 0.03, w = 0.94, h = 0.94 })
  end)
end

function HK_bottomHalfWindow()
  withFocused(function(win)
    tile(win, { x = 0, y = 0.5, w = 1, h = 0.5 })
  end)
end

function HK_bottomLeftQuarterWindow()
  withFocused(function(win)
    tile(win, { x = 0, y = 0.5, w = 0.5, h = 0.5 })
  end)
end

function HK_bottomRightQuarterWindow()
  withFocused(function(win)
    tile(win, { x = 0.5, y = 0.5, w = 0.5, h = 0.5 })
  end)
end

function HK_leftHalfWindow()
  withFocused(function(win)
    tile(win, { x = 0, y = 0, w = 0.5, h = 1 })
  end)
end

function HK_maximizeWindow()
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
    tile(win, { x = 0.5, y = 0, w = 0.5, h = 1 })
  end)
end

function HK_topHalfWindow()
  withFocused(function(win)
    tile(win, { x = 0, y = 0, w = 1, h = 0.5 })
  end)
end

function HK_topLeftQuarterWindow()
  withFocused(function(win)
    tile(win, { x = 0, y = 0, w = 0.5, h = 0.5 })
  end)
end

function HK_topRightQuarterWindow()
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
