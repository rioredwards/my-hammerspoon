local constants = require "config.constants"

-- logger module
-- Wraps console and alert logging functions into a single module
-- And adds log levels (log, error, success, warn)

local log = {}     -- aggregates all loggers into a single module

local console = {} -- console logging functions
local alert = {}   -- alert logging functions
local all = {}     -- logs messages to both console and alert

function console.setup()
  hs.console.darkMode(true)
  hs.console.outputBackgroundColor(constants.COLOR_BG_DEFAULT)
  hs.console.consoleCommandColor(constants.COLOR_FG)
  hs.console.consolePrintColor(constants.COLOR_FG)
  hs.console.alpha(1)

  -- output newlines to indicate separate run
  print("\n\n--------------------------------\n\n")
end

function console.log(message)
  hs.console.consolePrintColor(constants.COLOR_FG)
  print(message)
end

function console.error(message)
  hs.console.consolePrintColor(constants.COLOR_BG_ERROR)
  print(message)
  hs.console.consolePrintColor(constants.COLOR_FG)
end

function console.success(message)
  hs.console.consolePrintColor(constants.COLOR_BG_SUCCESS)
  print(message)
  hs.console.consolePrintColor(constants.COLOR_FG)
end

function console.warn(message)
  hs.console.consolePrintColor(constants.COLOR_BG_WARNING)
  print(message)
  hs.console.consolePrintColor(constants.COLOR_FG)
end

-- hs.alert.show(str, [style], [screen], [seconds]) -> uuid

local function truncateMessage(message)
  -- if its not a string, return the message
  if type(message) ~= "string" then
    return message
  end
  -- if its an empty string, return an empty string
  if message == "" then
    return ""
  end
  -- Truncate message to 100 characters
  local truncatedMessage = string.sub(message, 1, constants.ALERT_MESSAGE_MAX_LENGTH)
  -- Add ellipsis if message is truncated
  if string.len(truncatedMessage) < string.len(message) then
    truncatedMessage = truncatedMessage .. "..."
  end
  return truncatedMessage
end

function alert.log(message, duration)
  duration = duration or constants.ALERT_DEFAULT_DURATION
  message = truncateMessage(message)
  hs.alert.show(message, constants.ALERT_STYLE_DEFAULT, hs.screen.mainScreen(), duration)
end

function alert.error(message, duration)
  duration = duration or constants.ALERT_ERROR_DURATION
  message = truncateMessage(message)
  hs.alert.show(message, constants.ALERT_STYLE_ERROR, hs.screen.mainScreen(), duration)
end

function alert.success(message, duration)
  duration = duration or constants.ALERT_SUCCESS_DURATION
  message = truncateMessage(message)
  hs.alert.show(message, constants.ALERT_STYLE_SUCCESS, hs.screen.mainScreen(), duration)
end

function alert.warn(message, duration)
  duration = duration or constants.ALERT_WARNING_DURATION
  message = truncateMessage(message)
  hs.alert.show(message, constants.ALERT_STYLE_WARNING, hs.screen.mainScreen(), duration)
end

local function testAlerts()
  alert.log("Default alert", 8)
  alert.warn("Warning alert", 8)
  alert.error("Error alert", 8)
  alert.success("Success alert", 8)
end

function alert.setup()
  -- testAlerts()
end

function all.log(message, duration)
  duration = duration or constants.ALERT_DEFAULT_DURATION
  console.log(message)
  alert.log(message, duration)
end

function all.error(message, duration)
  duration = duration or constants.ALERT_ERROR_DURATION
  console.error(message)
  alert.error(message, duration)
end

function all.success(message, duration)
  duration = duration or constants.ALERT_SUCCESS_DURATION
  console.success(message)
  alert.success(message, duration)
end

function all.warn(message, duration)
  duration = duration or constants.ALERT_WARNING_DURATION
  console.warn(message)
  alert.warn(message, duration)
end

function all.setup()
  -- console.setup()
  -- alert.setup()
end

log.console = console
log.alert = alert
log.all = all

return log
