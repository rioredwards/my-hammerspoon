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

-- Phase 2: Create context object
local ctx = contextModule.create(
  log,
  configModules.constants,
  utils,
  status
)

-- Update context with status (circular dependency resolved)
ctx.status = status

-- Phase 3: Feature registry
-- Define all features to load, in order
-- Hotkeys must be loaded last since they depend on HK_ functions
local features = {
  -- Status dashboard (load early to track other features)
  { name = "statusDashboard",                        path = "features.statusDashboard" },
  -- Utility features
  { name = "windows",                                path = "features.windows" },
  { name = "showCalendar",                           path = "features.showCalendar" },
  { name = "keyCapture",                             path = "features.keyCapture" },
  { name = "openYoutubeLinksInCorrectChromeProfile", path = "features.openYoutubeLinksInCorrectChromeProfile" },
  { name = "ensureLocalServer",                      path = "features.ensureLocalServer" },
  { name = "webview",                                path = "features.webview" },
  { name = "lockScreen",                             path = "features.lockScreen" },
  { name = "reloadConfigurationDebounced",           path = "features.reloadConfigurationDebounced" },
  { name = "screenshot",                             path = "features.screenshot" },
  { name = "appSwitcher",                            path = "features.appSwitcher" },
  { name = "iterm2",                                 path = "features.iterm2" },
  -- Hotkey system (must be last)
  { name = "hotkeyJsonLoader",                       path = "hotkeys.hotkeyJsonLoader" },
  { name = "hotkeys",                                path = "hotkeys.hotkeys" },
  { name = "appLayer",                               path = "features.appLayer" },
}

-- Phase 4: Load features as plugins
local loadedFeatures = {}

for _, feature in ipairs(features) do
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

-- Phase 5: Configure Hammerspoon
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
