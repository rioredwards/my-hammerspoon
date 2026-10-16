-- My Controls HUD toggle via deep link

local M = {}

local ctx = nil

-- Fast path: if the app already answers /health, fire the link at once (no
-- login shell). Otherwise start the always-on dev app under pm2, wait until it
-- answers, then fire the link. Firing first while it is down opens a bare
-- Electron window.
local ENSURE = os.getenv("HOME") .. "/dev/my-controls/scripts/ensure-running.sh"
local HEALTH = "http://127.0.0.1:7357/health"
local HEALTH_TIMEOUT = 0.3

local function fire(url, label)
  hs.urlevent.openURL(url)
  ctx.log.console.log("My Controls: " .. label)
end

local function startThenFire(url, label)
  hs.task.new("/bin/zsh", function(code, _, stderr)
    if code ~= 0 then
      hs.alert.show("My Controls did not start: " .. stderr)
      ctx.log.console.error("My Controls: " .. stderr)
      return
    end
    fire(url, label)
  end, { "-lc", "'" .. ENSURE .. "'" }):start()
end

local function openLink(url, label)
  local settled = false
  local timer = hs.timer.doAfter(HEALTH_TIMEOUT, function()
    if settled then return end
    settled = true
    startThenFire(url, label)
  end)
  hs.http.asyncGet(HEALTH, nil, function(status)
    if settled then return end
    settled = true
    timer:stop()
    if status == 200 then
      fire(url, label)
    else
      startThenFire(url, label)
    end
  end)
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
