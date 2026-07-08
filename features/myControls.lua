-- My Controls HUD toggle via deep link

local M = {}

local ctx = nil

function HK_myControlsToggle()
  hs.execute("open 'mycontrols://window/toggle'")
  ctx.log.console.log("My Controls: toggle")
end

function M.init(context)
  local result = require "core.utils.result"
  ctx = context
  ctx.log.console.success("My Controls feature initialized")
  return result.ok()
end

return M
