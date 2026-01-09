local log = require "core.log"

-- Helper functions for safe module loading and function calls

local coreUtils = {}

-- Helper function to safely require modules
function coreUtils.safeRequire(moduleName)
  local success, result = pcall(function()
    return require(moduleName)
  end)

  if not success then
    local errorMsg = "Failed to load module '" .. moduleName
    log.alert.error(errorMsg)
    log.all.error(errorMsg .. ": " .. tostring(result))
    return nil
  end

  return result
end

-- Helper function to safely call functions
function coreUtils.safeCall(funcName, func, ...)
  if not func then
    local errorMsg = string.format("Function '%s' is not available (module may have failed to load)", funcName)
    log.all.error(errorMsg)
    return false
  end

  local success, result = pcall(func, ...)

  if not success then
    local errorMsg = "Function failed: '" .. funcName .. "' with error: " .. tostring(result)
    log.alert.error(errorMsg)
    log.all.error(errorMsg .. ": " .. tostring(result))
    return false
  end

  return true, result
end

-- Check if a port is in use
function coreUtils.G_isPortInUse(port)
  local command = string.format("lsof -i :%d", port)
  local output, status = hs.execute(command)
  return status == true and output ~= ""
end

-- Using shell scripts to avoid focusing raycast
function coreUtils.openDeepLinkWithoutFocusingApp(url)
  -- using os.execute for faster execution
  os.execute("open -g " .. url)
  -- slightly slower than os.execute, but more robust
  -- hs.task.new("/bin/bash", nil, {"-c", "open -g " .. url}):start()
end

return coreUtils
