-- My Controls HUD toggle via deep link

local M = {}

local ctx = nil

-- Starts the always-on dev app under pm2 if it is down, waits until it answers,
-- then fires the link. Firing first while it is down opens a bare Electron window.
local ENSURE = os.getenv("HOME") .. "/dev/my-controls/scripts/ensure-running.sh"

local function openLink(url, label)
  hs.task.new("/bin/zsh", function(code, _, stderr)
    if code ~= 0 then
      hs.alert.show("My Controls did not start: " .. stderr)
      ctx.log.console.error("My Controls: " .. stderr)
      return
    end
    hs.execute("open '" .. url .. "'")
    ctx.log.console.log("My Controls: " .. label)
  end, { "-lc", "'" .. ENSURE .. "'" }):start()
end

function HK_myControlsToggle()
  openLink("mycontrols-dev://window/toggle", "toggle")
end

function HK_agentAudioReader()
  openLink("mycontrols-dev://reader/toggle", "toggle Agent Audio reader")
end

function M.init(context)
  local result = require "core.utils.result"
  ctx = context
  ctx.log.console.success("My Controls feature initialized")
  return result.ok()
end

return M
