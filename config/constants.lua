-- Configuration constants for Hammerspoon
-- All configurable values are centralized here

local constants = {}

-- Colors
-- hsl(0, 0%, 22%);
constants.COLOR_FG = { hue = 0.0, saturation = 0.0, brightness = 0.9, alpha = 1.0 }
constants.COLOR_BG_DEFAULT = { hue = 0.58, saturation = 0.6, brightness = 0.4, alpha = 0.8 }
constants.COLOR_BORDER_DEFAULT = { hue = 0.58, saturation = 0.6, brightness = 0.4, alpha = 0.97 }
constants.COLOR_BG_SUCCESS = { hue = 0.3, saturation = 0.6, brightness = 0.4, alpha = 0.8 }
constants.COLOR_BORDER_SUCCESS = { hue = 0.3, saturation = 0.6, brightness = 0.4, alpha = 0.97 }
constants.COLOR_BG_WARNING = { hue = 0.15, saturation = 0.6, brightness = 0.4, alpha = 0.8 }
constants.COLOR_BORDER_WARNING = { hue = 0.15, saturation = 0.6, brightness = 0.4, alpha = 0.97 }
constants.COLOR_BG_ERROR = { hue = 0.0, saturation = 0.6, brightness = 0.4, alpha = 0.8 }
constants.COLOR_BORDER_ERROR = { hue = 0.0, saturation = 0.6, brightness = 0.4, alpha = 0.97 }

-- Hotkey JSON loader
constants.HOTKEY_JSON_PATH = "~/.hammerspoon/config/hotkeys.hammerspoon.json"

-- Alert message max length
constants.ALERT_MESSAGE_MAX_LENGTH = 100

-- Reload configuration debounce
constants.THROTTLE_DELAY = 10.0 -- seconds

-- Lock screen timer
constants.LOCK_SCREEN_TIME = "22:00"                                 -- 10:00 PM
constants.LOCK_SCREEN_WARN_TIMES = { 60, 30, 15, 10, 5, 4, 3, 2, 1 } -- Warnings at 60, 30, 15, 10, 5, 4, 3, 2, and 1 minutes before lock time

-- Calendar positioning (as percentages of screen)
constants.CALENDAR_X_OFFSET = 0.15          -- 15% from left
constants.CALENDAR_Y_OFFSET = 0.1           -- 10% from top
constants.CALENDAR_WIDTH = 0.7              -- 70% of screen width
constants.CALENDAR_HEIGHT = 0.8             -- 80% of screen height
constants.CALENDAR_ANIMATION_DURATION = 0.2 -- seconds

-- Webview configuration
constants.WEBVIEW_WIDTH_PERCENT = 0.98         -- 98% of screen width
constants.WEBVIEW_HEIGHT_PERCENT = 0.98        -- 98% of screen height
constants.WEBVIEW_GENERIC_URL = "https://www.hammerspoon.org"
constants.WEBVIEW_GENERIC_WIDTH_PERCENT = 0.8  -- 80% of screen width
constants.WEBVIEW_GENERIC_HEIGHT_PERCENT = 0.8 -- 80% of screen height

-- Local server ports
constants.LOCAL_SERVER_PORT = 1200     -- Production server port
constants.LOCAL_DEV_SERVER_PORT = 1201 -- Development server port

-- Alert styles
constants.ALERT_DEFAULT_DURATION = 2.0 -- seconds
constants.ALERT_WARNING_DURATION = 4.0 -- seconds
constants.ALERT_ERROR_DURATION = 6.0   -- seconds
constants.ALERT_SUCCESS_DURATION = 4.0 -- seconds
constants.ALERT_STYLE_BASE = {
  fillColor    = constants.COLOR_BG_DEFAULT,
  textColor    = constants.COLOR_FG,
  strokeColor  = constants.COLOR_BORDER_DEFAULT,
  textFont     = ".AppleSystemUIFont",
  textSize     = 16,
  radius       = 23,
  strokeWidth  = 3,
  atScreenEdge = 0, -- 0 means center, 1 means top, 2 means bottom
  padding      = 12,
}

constants.ALERT_STYLE_ERROR = {
  textFont = constants.ALERT_STYLE_BASE.textFont,
  textSize = constants.ALERT_STYLE_BASE.textSize,
  radius = constants.ALERT_STYLE_BASE.radius,
  strokeWidth = constants.ALERT_STYLE_BASE.strokeWidth,
  -- Overrides
  fillColor = constants.COLOR_BG_ERROR,
  textColor = constants.COLOR_FG,
  strokeColor = constants.COLOR_BORDER_ERROR,
  atScreenEdge = constants.ALERT_STYLE_BASE.atScreenEdge,
  padding = constants.ALERT_STYLE_BASE.padding,
}

constants.ALERT_STYLE_SUCCESS = {
  textFont = constants.ALERT_STYLE_BASE.textFont,
  textSize = constants.ALERT_STYLE_BASE.textSize,
  radius = constants.ALERT_STYLE_BASE.radius,
  strokeWidth = constants.ALERT_STYLE_BASE.strokeWidth,
  -- Overrides
  fillColor = constants.COLOR_BG_SUCCESS,
  textColor = constants.COLOR_FG,
  strokeColor = constants.COLOR_BORDER_SUCCESS,
  atScreenEdge = constants.ALERT_STYLE_BASE.atScreenEdge,
  padding = constants.ALERT_STYLE_BASE.padding,
}

constants.ALERT_STYLE_WARNING = {
  textFont = constants.ALERT_STYLE_BASE.textFont,
  textSize = constants.ALERT_STYLE_BASE.textSize,
  radius = constants.ALERT_STYLE_BASE.radius,
  strokeWidth = constants.ALERT_STYLE_BASE.strokeWidth,
  -- Overrides
  fillColor = constants.COLOR_BG_WARNING,
  textColor = constants.COLOR_FG,
  strokeColor = constants.COLOR_BORDER_WARNING,
  atScreenEdge = constants.ALERT_STYLE_BASE.atScreenEdge,
  padding = constants.ALERT_STYLE_BASE.padding,
}

constants.ALERT_STYLE_DEFAULT = {
  textFont = constants.ALERT_STYLE_BASE.textFont,
  textSize = constants.ALERT_STYLE_BASE.textSize,
  radius = constants.ALERT_STYLE_BASE.radius,
  strokeWidth = constants.ALERT_STYLE_BASE.strokeWidth,
  -- Overrides
  fillColor = constants.COLOR_BG_DEFAULT,
  textColor = constants.COLOR_FG,
  strokeColor = constants.COLOR_BORDER_DEFAULT,
  atScreenEdge = constants.ALERT_STYLE_BASE.atScreenEdge,
  padding = constants.ALERT_STYLE_BASE.padding,
}

return constants
