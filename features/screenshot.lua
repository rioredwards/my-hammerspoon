-- Screenshot functionality using CleanShot and Raycast

local M = {}

local ctx = nil

function HK_screenshotCaptureArea()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("cleanshot://capture-area")
  end
end

function HK_screenshotCaptureFullscreen()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("cleanshot://capture-fullscreen")
  end
end

function HK_screenshotCaptureAllInOne()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("cleanshot://all-in-one")
  end
end

function HK_screenshotOpenHistory()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("cleanshot://open-history")
  end
end

function HK_screenshotSearchScreenshots()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/screenshots/search-screenshots")
  end
end

function HK_screenshotCaptureText()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("cleanshot://capture-text")
  end
end

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  ctx.log.console.success("Screenshot feature initialized")

  return result.ok()
end

return M
