-- iTerm2-specific hotkey functions (AppleScript, no keystrokes)

local M = {}
local ctx = nil

local function iterm2IsFrontmost()
  local frontmostApp = hs.application.frontmostApplication()
  return frontmostApp and frontmostApp:bundleID() == "com.googlecode.iterm2"
end

local function runInCurrentITermSession(command)
  -- login shell so PATH/env matches your normal zsh env
  local wrapped = string.format([[zsh -lic %q]], command)

  local osa = string.format([[
    tell application "iTerm"
      if not (exists current window) then return
      tell current window
        if not (exists current session) then return
        tell current session
          write text %q
        end tell
      end tell
    end tell
  ]], wrapped)

  local ok, resultOrErr = hs.osascript.applescript(osa)
  if not ok and ctx and ctx.log and ctx.log.console then
    ctx.log.console.error("iTerm2 AppleScript failed: " .. tostring(resultOrErr))
  end
end

function HK_iterm2FzCmd()
  if not ctx then return end
  if not iterm2IsFrontmost() then return end

  -- If you want it to run in the existing session:
  runInCurrentITermSession("fzf-cmd")
end

function M.init(context)
  local result = require "core.utils.result"
  ctx = context
  ctx.log.console.success("iTerm2 feature initialized")
  return result.ok()
end

return M
