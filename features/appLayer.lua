-- Application-specific hotkey layer system
-- Monitors active application and binds/unbinds app-specific hotkeys dynamically

local M = {}
local hotkeyJsonLoader = require "hotkeys.hotkeyJsonLoader"

local ctx = nil
local appWatcher = nil
local currentAppLayer = nil
local currentAppHotkeys = {} -- Table of currently active hotkey objects
local appLayersData = {}     -- Cached app layer definitions from JSON
local appLayerHotkeys = {}   -- Cache of hotkey objects per bundle ID (so we can re-enable them)

-- Get the bundle ID of the currently focused application
local function getCurrentAppBundleId()
  local app = hs.application.frontmostApplication()
  if app then
    return app:bundleID()
  end
  return nil
end

-- Disable all currently active app layer hotkeys (but keep them cached for re-enabling)
local function disableCurrentAppLayer()
  if not currentAppHotkeys or #currentAppHotkeys == 0 then
    return
  end

  for _, hotkeyObj in ipairs(currentAppHotkeys) do
    if hotkeyObj and type(hotkeyObj) == "userdata" then
      -- Disable the hotkey (wrapped in pcall to handle any errors gracefully)
      local success, err = pcall(function() hotkeyObj:disable() end)
      if not success and ctx then
        ctx.log.console.warn(string.format("Failed to disable hotkey: %s", tostring(err)))
      end
    end
  end

  currentAppHotkeys = {}
  currentAppLayer = nil
end

-- Enable hotkeys for a specific app layer
local function enableAppLayer(bundleId, layerData)
  if not ctx or not bundleId or not layerData then
    return
  end

  -- Disable any existing app layer hotkeys first
  disableCurrentAppLayer()

  if not layerData.hotkeys or #layerData.hotkeys == 0 then
    return
  end

  -- Check if we already have hotkeys created for this bundle ID
  if appLayerHotkeys[bundleId] then
    -- Re-enable existing hotkeys
    for _, hotkeyObj in ipairs(appLayerHotkeys[bundleId]) do
      hotkeyObj:enable()
    end
    currentAppLayer = bundleId
    currentAppHotkeys = appLayerHotkeys[bundleId]
    return
  end

  -- Transform app layer hotkeys using the existing transformation logic
  local hotkeysTable = hotkeyJsonLoader.transformAppLayerHotkeys(layerData.hotkeys)

  -- Create and enable each hotkey
  local hotkeyObjects = {}
  for _, hotkey in ipairs(hotkeysTable) do
    if not hotkey.action then
      goto continue
    end

    -- Create the hotkey (disabled by default with hs.hotkey.new)
    local hotkeyObj = hs.hotkey.new(hotkey.mods, hotkey.key, hotkey.action)
    hotkeyObj:enable()
    table.insert(hotkeyObjects, hotkeyObj)

    ::continue::
  end

  -- Cache the hotkeys for this bundle ID so we can re-enable them later
  appLayerHotkeys[bundleId] = hotkeyObjects
  currentAppHotkeys = hotkeyObjects
  currentAppLayer = bundleId
end

-- Handle application activation/focus changes
local function handleAppChange(name, eventType, app)
  if not ctx then
    return
  end

  if eventType == hs.application.watcher.activated then
    local bundleId = app:bundleID()
    if not bundleId then
      return
    end

    -- Check if we have a layer defined for this app
    local layerData = appLayersData[bundleId]
    if layerData then
      enableAppLayer(bundleId, layerData)
    else
      -- App changed but no layer defined, disable any active hotkeys
      -- Always check and disable if there are hotkeys active (ensures cleanup even if state is inconsistent)
      if currentAppHotkeys and #currentAppHotkeys > 0 then
        disableCurrentAppLayer()
      end
    end
  end
end

-- Load app layers from JSON (reuses existing hotkeyJsonLoader functionality)
local function loadAppLayersFromJson()
  if not ctx then
    return
  end

  if not _G.G_loadAppLayersFromJson then
    ctx.log.all.error("Error: G_loadAppLayersFromJson not available (hotkeyJsonLoader must load first)")
    return
  end

  appLayersData = _G.G_loadAppLayersFromJson()

  local count = 0
  for _ in pairs(appLayersData) do
    count = count + 1
  end
  if count > 0 then
    ctx.log.console.log(string.format("Loaded app layers for %d applications", count))
  end
end

-- Helper function to get current app bundle ID (useful for debugging)
function G_getCurrentAppBundleId()
  return getCurrentAppBundleId()
end

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  -- Load app layers from JSON
  loadAppLayersFromJson()

  -- Create application watcher
  appWatcher = hs.application.watcher.new(handleAppChange)
  appWatcher:start()

  -- Trigger initial app layer enabling for current app
  local currentBundleId = getCurrentAppBundleId()
  if currentBundleId and appLayersData[currentBundleId] then
    enableAppLayer(currentBundleId, appLayersData[currentBundleId])
  end

  -- Export helper function to global scope
  _G.G_getCurrentAppBundleId = G_getCurrentAppBundleId

  ctx.log.console.success("AppLayer feature initialized")

  return result.ok()
end

return M
