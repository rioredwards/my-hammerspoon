-- Lock screen scheduler
-- This function will lock the screen at a set time every night

local M = {}

local ctx = nil
local lockScreenTimer = nil
local warnBeforeLockScreenTimers = {}

local function lockScreen()
  hs.caffeinate.lockScreen()
end

-- Helper function to subtract minutes from a time string (HH:MM format)
local function subtractMinutesFromTime(timeStr, minutes)
  local hour, min = timeStr:match("(%d+):(%d+)")
  hour = tonumber(hour)
  min = tonumber(min)

  -- Convert to total minutes since midnight
  local totalMinutes = hour * 60 + min - minutes

  -- Handle wrap-around (if negative, add 24 hours)
  if totalMinutes < 0 then
    totalMinutes = totalMinutes + 24 * 60
  end

  -- Convert back to hours and minutes
  local newHour = math.floor(totalMinutes / 60) % 24
  local newMin = totalMinutes % 60

  -- Format back to HH:MM
  return string.format("%02d:%02d", newHour, newMin)
end

-- Start the daily lock screen timer with warnings before the lock time
-- minutes can be a single number or an array of numbers
function G_startLockScreenTimer(time, minutes)
  if not ctx then
    return
  end

  -- Stop existing timers if they exist
  if lockScreenTimer then
    lockScreenTimer:stop()
    lockScreenTimer = nil
  end

  -- Stop all existing warning timers
  for _, timer in ipairs(warnBeforeLockScreenTimers) do
    timer:stop()
  end
  warnBeforeLockScreenTimers = {}

  -- Normalize minutes to an array (handle both single value and array)
  local minutesArray = type(minutes) == "table" and minutes or { minutes }

  -- Create warning timers for each minute value
  local warningTimes = {}
  for _, min in ipairs(minutesArray) do
    local warningTime = subtractMinutesFromTime(time, min)
    table.insert(warningTimes, warningTime)

    -- Create a daily repeating timer for this warning
    local timer = hs.timer.doAt(warningTime, "1d", function()
      ctx.log.all.warn("Locking screen in " .. min .. " minutes")
    end)
    table.insert(warnBeforeLockScreenTimers, timer)
  end

  -- Create a daily repeating timer for the actual lock
  -- "1d" means it will repeat every 24 hours at the specified time
  lockScreenTimer = hs.timer.doAt(time, "1d", lockScreen)

  -- Show confirmation message
  local warningMsg = #warningTimes > 0 and (" (warnings at " .. table.concat(warningTimes, ", ") .. ")") or ""
  ctx.log.console.log("Screen will lock daily at " .. time .. warningMsg)
end

-- Stop the lock screen timer
function G_stopLockScreenTimer()
  if lockScreenTimer then
    lockScreenTimer:stop()
    lockScreenTimer = nil
  end

  -- Stop all warning timers
  for _, timer in ipairs(warnBeforeLockScreenTimers) do
    timer:stop()
  end
  warnBeforeLockScreenTimers = {}
end

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  -- Export functions to global scope
  _G.G_startLockScreenTimer = G_startLockScreenTimer
  _G.G_stopLockScreenTimer = G_stopLockScreenTimer

  -- Start the timer if constants are configured
  if ctx.constants.LOCK_SCREEN_TIME then
    G_startLockScreenTimer(
      ctx.constants.LOCK_SCREEN_TIME,
      ctx.constants.LOCK_SCREEN_WARN_TIMES
    )
  end

  ctx.log.console.success("LockScreen feature initialized")

  return result.ok()
end

return M
