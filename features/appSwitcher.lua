-- App Switcher (AltTab) integration
-- Provides hotkey functions to trigger AltTab app and window switchers

local M = {}

local ctx = nil

-- Path to AltTab executable
local ALTTAB_PATH = "/Applications/AltTab.app/Contents/MacOS/AltTab"

-- Show app switcher (AltTab --show=0)
function HK_showAppSwitcher()
  if ctx then
    local command = ALTTAB_PATH .. " --show=0"
    os.execute(command)
    ctx.log.console.log("Triggered app switcher")
  end
end

-- Show window switcher (AltTab --show=1)
function HK_showWindowSwitcher()
  if ctx then
    local command = ALTTAB_PATH .. " --show=1"
    os.execute(command)
    ctx.log.console.log("Triggered window switcher")
  end
end

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  ctx.log.console.success("AppSwitcher feature initialized")

  return result.ok()
end

return M
