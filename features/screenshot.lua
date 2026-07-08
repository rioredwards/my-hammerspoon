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

-- Expand a leading ~ to $HOME (only the leading char, like the hotkey loader).
local function expandHome(path)
  if path:sub(1, 1) == "~" then
    return os.getenv("HOME") .. path:sub(2)
  end
  return path
end

-- Percent-encode a filesystem path for a URL, preserving path separators.
local function encodePathForUrl(path)
  return (path:gsub("[^%w%-%._~/]", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

-- Open the most recently modified screenshot in CleanShot's annotate tool.
function HK_screenshotAnnotateLast()
  if not ctx then
    return
  end

  local dir = expandHome(ctx.constants.SCREENSHOT_DIR)

  local listCmd = string.format(
    'cd %q && ls -t *.png *.jpg *.jpeg *.PNG *.JPG *.JPEG 2>/dev/null | head -1',
    dir
  )
  local filename = hs.execute(listCmd)
  filename = filename and filename:gsub("%s+$", "") or ""

  if filename == "" then
    ctx.log.all.warn("No screenshot found in " .. dir)
    return
  end

  local fullPath = dir .. "/" .. filename
  local url = "cleanshot://open-annotate?filepath=" .. encodePathForUrl(fullPath)
  ctx.utils.openDeepLinkWithoutFocusingApp(url)
end

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  ctx.log.console.success("Screenshot feature initialized")

  return result.ok()
end

return M
