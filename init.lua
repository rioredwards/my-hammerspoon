-- Hammerspoon Configuration Bootstrapper
-- Loads core modules, creates context, and initializes features as plugins

-- Phase 1: Load core modules (hard-fail if these fail)
local core = require "core.index"
local config = require "config.index"

-- Initialize core modules
local coreModules = core.init()
local configModules = config.init()

-- Extract core dependencies
local log = coreModules.log
local utils = coreModules.utils
local result = coreModules.result
local contextModule = coreModules.context
local status = coreModules.status
local settingsKey = "hammerspoon.disabledFeatures"

-- Phase 2: Create context object
local ctx = contextModule.create(
  log,
  configModules.constants,
  utils,
  status
)

-- Update context with status (circular dependency resolved)
ctx.status = status

local function loadDisabledFeatureMap()
  local stored = hs.settings.get(settingsKey)
  local disabled = {}

  if type(stored) == "table" then
    for _, name in ipairs(stored) do
      if type(name) == "string" and name ~= "" then
        disabled[name] = true
      end
    end
  end

  return disabled
end

local function saveDisabledFeatureMap(disabledMap)
  local names = {}

  for name, isDisabled in pairs(disabledMap) do
    if isDisabled then
      table.insert(names, name)
    end
  end

  table.sort(names)
  hs.settings.set(settingsKey, names)
end

-- Phase 3: Feature registry
-- Define all features to load, in order
-- Hotkeys must be loaded last since they depend on HK_ functions
local features = {
  -- Status dashboard (load early to track other features)
  { name = "statusDashboard",                        path = "features.statusDashboard",                       locked = true },
  { name = "straightawayDashboard",                  path = "features.straightawayDashboard" },
  -- Utility features
  { name = "windows",                                path = "features.windows" },
  { name = "showCalendar",                           path = "features.showCalendar" },
  { name = "keyCapture",                             path = "features.keyCapture" },
  { name = "openYoutubeLinksInCorrectChromeProfile", path = "features.openYoutubeLinksInCorrectChromeProfile" },
  { name = "ensureLocalServer",                      path = "features.ensureLocalServer" },
  { name = "webview",                                path = "features.webview" },
  -- { name = "lockScreen",                             path = "features.lockScreen" },
  { name = "reloadConfigurationDebounced",           path = "features.reloadConfigurationDebounced" },
  { name = "screenshot",                             path = "features.screenshot" },
  { name = "todaybar",                                path = "features.todaybar" },
  { name = "myControls",                             path = "features.myControls" },
  { name = "clipboard",                              path = "features.clipboard" },
  { name = "appSwitcher",                            path = "features.appSwitcher" },
  { name = "iterm2",                                 path = "features.iterm2" },
  { name = "appLauncher",                            path = "features.appLauncher" },
  { name = "search",                                 path = "features.search" },
  { name = "pickColor",                              path = "features.pickColor" },
  { name = "playAgentAudio",                         path = "features.playAgentAudio" },
  { name = "agentAudioWebview",                      path = "features.agentAudioWebview" },
  { name = "larryPet",                               path = "features.larryPet" },
  { name = "automationCue",                          path = "features.automationCue" },
  { name = "clipboardFormatter",                      path = "features.clipboardFormatter" },
  -- Hotkey system (must be last)
  { name = "hotkeyJsonLoader",                       path = "hotkeys.hotkeyJsonLoader" },
  { name = "hotkeys",                                path = "hotkeys.hotkeys" },
  -- { name = "appLayer",                               path = "features.appLayer" },
}

local disabledFeatures = loadDisabledFeatureMap()

local function isFeatureLocked(featureName)
  for _, feature in ipairs(features) do
    if feature.name == featureName then
      return feature.locked == true
    end
  end

  return false
end

for _, feature in ipairs(features) do
  if feature.locked then
    disabledFeatures[feature.name] = nil
  end
end

saveDisabledFeatureMap(disabledFeatures)

local function isFeatureEnabled(featureName)
  if isFeatureLocked(featureName) then
    return true
  end

  return not disabledFeatures[featureName]
end

local function setFeatureEnabled(featureName, enabled)
  if isFeatureLocked(featureName) then
    return
  end

  if enabled then
    disabledFeatures[featureName] = nil
  else
    disabledFeatures[featureName] = true
  end

  saveDisabledFeatureMap(disabledFeatures)
end

local function toggleFeature(featureName)
  setFeatureEnabled(featureName, not isFeatureEnabled(featureName))
end

ctx.features = {
  list = features,
  isEnabled = isFeatureEnabled,
  setEnabled = setFeatureEnabled,
  toggle = toggleFeature,
  isLocked = isFeatureLocked
}

-- Phase 4: Load features as plugins
local loadedFeatures = {}

for _, feature in ipairs(features) do
  if not isFeatureEnabled(feature.name) and not feature.locked then
    status.recordDisabled(feature.name, "Disabled in menu", { source = "menu" })
    log.console.log(string.format("Feature '%s' skipped (disabled in menu)", feature.name))
  else
    local success, module = pcall(function()
      return require(feature.path)
    end)

    if not success then
      -- Syntax error or module not found - hard fail for core issues
      local errorMsg = string.format("Failed to load module '%s': %s", feature.path, tostring(module))
      log.all.error(errorMsg)
      log.alert.error("Critical: " .. errorMsg)
      -- Continue loading other features, but record the failure
      status.record(feature.name, result.fail("MODULE_LOAD_ERROR", errorMsg))
    else
      -- Module loaded, try to initialize
      if type(module) == "table" and type(module.init) == "function" then
        local initSuccess, initResult = pcall(function()
          return module.init(ctx)
        end)

        if not initSuccess then
          -- Exception during init
          local errorMsg = string.format("Exception during init of '%s': %s", feature.name, tostring(initResult))
          log.all.error(errorMsg)
          status.record(feature.name, result.fail("INIT_EXCEPTION", errorMsg))
        elseif initResult and type(initResult) == "table" then
          -- Got a result table
          status.record(feature.name, initResult)

          if not initResult.ok then
            -- Feature failed to initialize
            local level = initResult.level or "error"
            local msg = string.format("Feature '%s' disabled: %s", feature.name, initResult.msg or "Unknown error")

            if level == "warn" then
              log.alert.warn(msg)
              log.all.error(msg)
            else
              log.all.error(msg)
            end
          else
            -- Feature initialized successfully
            loadedFeatures[feature.name] = module
            log.console.success(string.format("Feature '%s' loaded successfully", feature.name))
          end
        else
          -- No result returned, assume success
          status.record(feature.name, result.ok())
          loadedFeatures[feature.name] = module
          log.all.log(string.format("Feature '%s' loaded (no result returned)", feature.name))
        end
      else
        -- Module doesn't have init() - legacy module, assume success
        status.record(feature.name, result.ok({ legacy = true }))
        loadedFeatures[feature.name] = module
        log.all.log(string.format("Feature '%s' loaded (legacy module)", feature.name))
      end
    end
  end
end

-- Phase 5: Configure Hammerspoon
require("hs.ipc")
hs.allowAppleScript(true)
hs.application.enableSpotlightForNameSearches(true)

-- Phase 6: Update status dashboard if it was loaded
if loadedFeatures.statusDashboard and loadedFeatures.statusDashboard.update then
  loadedFeatures.statusDashboard.update(ctx)
end

-- Phase 7: Show startup notification
local summary = status.formatSummary()
local summaryDetails = status.summary()

if summaryDetails.error > 0 or summaryDetails.warn > 0 then
  log.alert.warn("Hammerspoon loaded: " .. summary, 3.0)
else
  log.alert.success("Hammerspoon loaded: " .. summary, 2.0)
end

log.console.success("Hammerspoon configuration loaded!")
log.console.log("Status: " .. summary)
