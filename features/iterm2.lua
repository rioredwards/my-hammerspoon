-- iTerm2-specific hotkey functions

local M = {}

local ctx = nil

-- Type "fz-cmd\n" in the current application
function HK_iterm2FzCmd()
  if ctx then
    -- sleep for 0.1 seconds
    hs.timer.doAfter(0.1, function()
      hs.eventtap.keyStrokes("fz-cmd\n")
    end)
  end
end

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  ctx.log.console.success("iTerm2 feature initialized")

  return result.ok()
end

return M

