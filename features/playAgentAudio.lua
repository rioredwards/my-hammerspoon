local M = {}

local ctx = nil

function HK_playAgentAudio()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/rio_edwards/rio-raycast-toolbox/play-agent-audio")
  end
end

function M.init(context)
  local result = require "core.utils.result"
  ctx = context
  ctx.log.console.success("PlayAgentAudio feature initialized")
  return result.ok()
end

return M
