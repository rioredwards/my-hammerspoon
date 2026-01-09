-- Context object creation
-- Builds and returns a context object containing all dependencies needed by features

local context = {}

-- Create a context object with all required dependencies
-- @param log Logging module
-- @param constants Configuration constants
-- @param utils Utility functions
-- @param status Status tracker (optional, added after status module is created)
-- @return Context table
function context.create(log, constants, utils, status)
  -- Notification helper function
  local function notify(message, level, duration)
    level = level or "log"
    duration = duration or 2.0

    if level == "error" then
      log.alert.error(message, duration)
    elseif level == "warn" then
      log.alert.warn(message, duration)
    elseif level == "success" then
      log.alert.success(message, duration)
    else
      log.alert.log(message, duration)
    end
  end

  return {
    log = log,
    constants = constants,
    utils = utils,
    status = status,
    notify = notify
  }
end

return context
