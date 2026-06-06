-- Clipboard typing utility

local M = {}

local ctx = nil
local typingTimer = nil
local typingRunId = 0
local cancelHotkey = nil

local INITIAL_DELAY = 0.5
local KEY_DELAY = 0.01

local CANCEL_MODS = {}
local CANCEL_KEY = "escape"

local function warn(message)
  if ctx then ctx.log.alert.warn(message) end
end

local function success(message)
  if ctx then ctx.log.alert.success(message) end
end

local function unregisterCancelHotkey()
  if cancelHotkey then
    cancelHotkey:delete()
    cancelHotkey = nil
  end
end

local function stopTyping()
  if typingTimer then
    typingTimer:stop()
    typingTimer = nil
  end

  unregisterCancelHotkey()
end

local function cancelTyping(message)
  typingRunId = typingRunId + 1
  stopTyping()

  if message then
    warn(message)
  end
end

local function registerCancelHotkey()
  if cancelHotkey then return end

  cancelHotkey = hs.hotkey.bind(CANCEL_MODS, CANCEL_KEY, function()
    M.cancelTypeClipboard()
  end)
end

local function nextUtf8Char(text, byteIndex)
  if byteIndex > #text then
    return nil, byteIndex
  end

  local nextIndex = utf8.offset(text, 2, byteIndex)

  if nextIndex then
    return text:sub(byteIndex, nextIndex - 1), nextIndex
  end

  return text:sub(byteIndex), #text + 1
end

function HK_typeClipboard()
  local text = hs.pasteboard.getContents()

  if not text or text == "" then
    warn("Clipboard empty")
    return
  end

  cancelTyping()

  typingRunId = typingRunId + 1
  local runId = typingRunId
  local byteIndex = 1

  registerCancelHotkey()

  hs.timer.doAfter(INITIAL_DELAY, function()
    if runId ~= typingRunId then return end

    typingTimer = hs.timer.doEvery(KEY_DELAY, function()
      if runId ~= typingRunId then
        stopTyping()
        return
      end

      local char
      char, byteIndex = nextUtf8Char(text, byteIndex)

      if not char then
        stopTyping()
        success("Typing complete")
        return
      end

      hs.eventtap.keyStrokes(char)
    end)
  end)
end

function M.cancelTypeClipboard()
  cancelTyping("Typing cancelled")
end

function M.init(context)
  local result = require "core.utils.result"

  ctx = context
  ctx.log.console.success("Clipboard typing initialized")

  return result.ok()
end

return M
