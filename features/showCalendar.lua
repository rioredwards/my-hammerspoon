-- Show Apple Calendar while holding hotkey

local M = {}

local ctx = nil
local calendarApp = nil
local previousApp = nil

local function showCalendar()
  calendarApp = hs.application.find("Calendar")

  if not calendarApp then
    hs.application.launchOrFocus("Calendar")
    calendarApp = hs.application.find("Calendar")
  end

  -- Store the current frontmost app
  previousApp = hs.application.frontmostApplication()
  ctx.log.console.log("Previous app: " .. previousApp:name())

  -- Show and position Calendar
  hs.application.launchOrFocus("Calendar")
  hs.timer.doAfter(0.1, function()
    local win = calendarApp:mainWindow()
    if win then
      local screenFrame = hs.screen.mainScreen():frame()
      local newFrame = hs.geometry.rect(
        screenFrame.x + (screenFrame.w * ctx.constants.CALENDAR_X_OFFSET),
        screenFrame.y + (screenFrame.h * ctx.constants.CALENDAR_Y_OFFSET),
        screenFrame.w * ctx.constants.CALENDAR_WIDTH,
        screenFrame.h * ctx.constants.CALENDAR_HEIGHT
      )
      win:setFrame(newFrame, ctx.constants.CALENDAR_ANIMATION_DURATION)
      win:focus()
    end
  end)
end

local function hideCalendar()
  if calendarApp then
    calendarApp:hide()
    -- Return to the previous app
    if previousApp then
      previousApp:activate()
    end
  end
end

function HK_toggleCalendar()
  calendarApp = hs.application.find("Calendar")

  -- If calendar app doesn't exist or isn't running, show it
  if not calendarApp or not calendarApp:isRunning() then
    showCalendar()
    return
  end

  -- Check if calendar is visible (has visible windows)
  local mainWin = calendarApp:mainWindow()
  local isVisible = mainWin and mainWin:isVisible()

  if isVisible then
    -- Calendar is visible, so hide it
    hideCalendar()
  else
    -- Calendar is running but hidden, so show it
    showCalendar()
  end
end

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  ctx.log.console.success("ShowCalendar feature initialized")

  return result.ok()
end

return M
