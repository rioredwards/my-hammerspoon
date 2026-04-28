local M = {}

local ctx = nil

function HK_pickColor()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/thomas/color-picker/pick-color")
  end
end

function M.init(context)
  local result = require "core.utils.result"
  ctx = context
  ctx.log.console.success("PickColor feature initialized")
  return result.ok()
end

return M
