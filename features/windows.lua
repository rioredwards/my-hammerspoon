-- Raycast deep link URLs for window management

local M = {}

local ctx = nil

function HK_almostMaximizeWindow()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/window-management/almost-maximize")
  end
end

function HK_bottomHalfWindow()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/window-management/bottom-half")
  end
end

function HK_bottomLeftQuarterWindow()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/window-management/bottom-left-quarter")
  end
end

function HK_bottomRightQuarterWindow()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/window-management/bottom-right-quarter")
  end
end

function HK_leftHalfWindow()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/window-management/left-half")
  end
end

function HK_maximizeWindow()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/window-management/maximize")
  end
end

function HK_restoreWindow()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/window-management/restore")
  end
end

function HK_rightHalfWindow()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/window-management/right-half")
  end
end

function HK_topHalfWindow()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/window-management/top-half")
  end
end

function HK_topLeftQuarterWindow()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/window-management/top-left-quarter")
  end
end

function HK_topRightQuarterWindow()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/window-management/top-right-quarter")
  end
end

-- Desktop/Space switching functions
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

  -- All HK_ functions are already exported to global scope
  ctx.log.console.success("Windows feature initialized")

  return result.ok()
end

return M
