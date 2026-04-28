-- Show Apple Calendar while holding hotkey

local M = {}

local ctx = nil

function launchApplication(appName)
  hs.application.launchOrFocus(appName)
  ctx.log.console.log("Launched application: " .. appName)
end

function HK_launchCalendar()
  launchApplication("Calendar")
end

function HK_launchChatGPT()
  launchApplication("ChatGPT")
end

function HK_launchCursor()
  launchApplication("Cursor")
end

function HK_launchFinder()
  launchApplication("Finder")
end

function HK_launchGoogleChrome()
  launchApplication("Google Chrome")
end

function HK_launchSlack()
  launchApplication("Slack")
end

function HK_launchSystemSettings()
  launchApplication("System Settings")
end

function HK_launchWarp()
  launchApplication("Warp")
end

function M.init(context)
  local result = require "core.utils.result"
  ctx = context
  ctx.log.console.success("AppLauncher feature initialized")
  return result.ok()
end

return M
