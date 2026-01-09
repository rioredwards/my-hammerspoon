-- Application-specific hotkey layer system
-- Monitors active application and binds/unbinds app-specific hotkeys dynamically

local M = {}
local hotkeyJsonLoader = require "hotkeys.hotkeyJsonLoader"

local ctx = nil
local appWatcher = nil
local currentAppLayer = nil
local currentAppHotkeys = {} -- Table of hotkey objects to track for cleanup
local appLayersData = {} -- Cached app layer definitions from JSON
local hotkeyRegistry = {} -- Registry of hotkey combinations to prevent duplicates

-- Get the bundle ID of the currently focused application
local function getCurrentAppBundleId()
  local app = hs.application.frontmostApplication()
  if app then
    return app:bundleID()
  end
  return nil
end

-- Unbind all currently active app layer hotkeys
local function unbindCurrentAppLayer()
  if not currentAppHotkeys or #currentAppHotkeys == 0 then
    return
  end

  for i, hotkeyObj in ipairs(currentAppHotkeys) do
    if hotkeyObj and type(hotkeyObj) == "userdata" then
      -- Delete the hotkey (wrapped in pcall to handle any errors gracefully)
      local success, err = pcall(function() hotkeyObj:delete() end)
      if not success and ctx then
        ctx.log.console.warn(string.format("Failed to delete hotkey: %s", tostring(err)))
      end
    end
  end

  currentAppHotkeys = {}
  currentAppLayer = nil
  hotkeyRegistry = {} -- Clear the registry when unbinding
end

-- Bind hotkeys for a specific app layer
local function bindAppLayer(bundleId, layerData)
  if not ctx or not bundleId or not layerData then
    return
  end

  -- Unbind any existing app layer hotkeys first
  unbindCurrentAppLayer()

  if not layerData.hotkeys or #layerData.hotkeys == 0 then
    return
  end

  -- Transform app layer hotkeys using the existing transformation logic
  local hotkeysTable = hotkeyJsonLoader.transformAppLayerHotkeys(layerData.hotkeys)

  -- Bind each hotkey with wrapped action
  for _, hotkey in ipairs(hotkeysTable) do
    if not hotkey.action then
      goto continue
    end

    -- Create a unique key for this hotkey combination to prevent duplicates
    local hotkeyKey = table.concat(hotkey.mods, ",") .. ":" .. hotkey.key
    
    -- Skip if this hotkey is already bound (shouldn't happen, but safety check)
    if hotkeyRegistry[hotkeyKey] then
      ctx.log.console.warn(string.format("Hotkey %s already bound, skipping duplicate", hotkeyKey))
      goto continue
    end

    -- Wrap the action to check if we're still in the correct app before executing
    -- This ensures the hotkey only works when the app layer is active
    local wrappedAction = function()
      if currentAppLayer == bundleId then
        hotkey.action()
      end
    end

    -- Bind the hotkey with the wrapped action
    local hotkeyObj = hs.hotkey.bind(hotkey.mods, hotkey.key, wrappedAction)
    table.insert(currentAppHotkeys, hotkeyObj)
    hotkeyRegistry[hotkeyKey] = true

    ::continue::
  end

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
      bindAppLayer(bundleId, layerData)
    else
      -- App changed but no layer defined, unbind any active hotkeys
      -- Always check and unbind if there are hotkeys bound (ensures cleanup even if state is inconsistent)
      if currentAppHotkeys and #currentAppHotkeys > 0 then
        unbindCurrentAppLayer()
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

  -- Trigger initial app layer binding for current app
  local currentBundleId = getCurrentAppBundleId()
  if currentBundleId and appLayersData[currentBundleId] then
    bindAppLayer(currentBundleId, appLayersData[currentBundleId])
  end

  -- Export helper function to global scope
  _G.G_getCurrentAppBundleId = G_getCurrentAppBundleId

  ctx.log.console.success("AppLayer feature initialized")

  return result.ok()
end

return M

