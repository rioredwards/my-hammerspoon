-- Throttled configuration reloader
-- Watches for file changes and reloads configuration with throttling
-- Triggers immediately on first change, then waits for throttle period before allowing next reload
-- Prevents multiple rapid reloads from causing issues

local M = {}

local ctx = nil
local throttleTimer = nil
local lastReloadTime = 0
local pathWatchers = {}

-- Throttled reload function
local function throttledReload()
  if not ctx then
    return
  end

  local currentTime = os.time()
  local timeSinceLastReload = currentTime - lastReloadTime

  -- If enough time has passed since last reload, trigger immediately
  if timeSinceLastReload >= ctx.constants.THROTTLE_DELAY then
    -- No pending timer, trigger immediately
    if throttleTimer then
      throttleTimer:stop()
      throttleTimer = nil
    end

    ctx.log.all.log("Reloading Hammerspoon configuration...")
    hs.reload()
    lastReloadTime = os.time()
  else
    -- Not enough time has passed, schedule for after the throttle period
    -- Only schedule if we don't already have a pending timer
    if not throttleTimer then
      local waitTime = ctx.constants.THROTTLE_DELAY - timeSinceLastReload
      throttleTimer = hs.timer.doAfter(waitTime, function()
        ctx.log.all.log("Reloading Hammerspoon configuration...")
        hs.reload()
        lastReloadTime = os.time()
        throttleTimer = nil
      end)
    end
  end
end

-- Start watching for configuration changes with throttling
function G_startReloadConfigurationDebounced()
  if not ctx then
    return
  end

  -- Stop any existing watchers
  for _, watcher in pairs(pathWatchers) do
    if watcher then
      watcher:stop()
    end
  end
  pathWatchers = {}

  -- Watch the Hammerspoon config directory
  local configDir = hs.configdir
  local success, watcher = pcall(function()
    return hs.pathwatcher.new(configDir, throttledReload)
  end)

  if not success then
    local errorMsg = string.format("Error creating path watcher for %s: %s", configDir, tostring(watcher))
    ctx.log.all.error(errorMsg)
    ctx.log.alert.error("Error setting up configuration watcher")
    return
  end

  if watcher then
    watcher:start()
    pathWatchers[configDir] = watcher
    ctx.log.console.log(string.format("Watching for configuration changes in: %s", configDir))
  else
    ctx.log.all.error("Failed to create path watcher")
  end
end

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  -- Export function to global scope
  _G.G_startReloadConfigurationDebounced = G_startReloadConfigurationDebounced

  -- Automatically start watching for changes
  G_startReloadConfigurationDebounced()

  ctx.log.console.success("ReloadConfigurationThrottled feature initialized and watching for changes")

  return result.ok()
end

return M
