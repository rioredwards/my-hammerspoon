-- Clipboard utilities

local M = {}

local ctx = nil

function HK_clipboardJoinLines()
  local text = hs.pasteboard.getContents()
  if not text or text == "" then return end

  text = text:gsub("\r\n", "\n")
      :gsub("\r", "\n")
      :gsub("^%s+", "")
      :gsub("%s+$", "")
      :gsub("\n+", " ")
      :gsub("%s%s+", " ")

  hs.pasteboard.setContents(text)
  if ctx then
    ctx.log.alert.success("Clipboard joined")
  end
end

function HK_clipboardTrimLines()
  local text = hs.pasteboard.getContents()
  if not text or text == "" then return end

  hs.timer.doAfter(0.1, function()
    local text = hs.pasteboard.getContents()
    if not text or text == "" then return end

    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")

    local lines = {}
    for line in text:gmatch("([^\n]*)\n?") do
      table.insert(lines, line:match("^%s*(.-)%s*$"))
    end
    text = table.concat(lines, "\n")
    text = text:gsub("^\n+", ""):gsub("\n+$", "")

    hs.pasteboard.setContents(text)
    if ctx then
      ctx.log.alert.success("Clipboard lines trimmed")
    end
  end)
end

function HK_copyAndTrimLines()
  hs.eventtap.keyStroke({ "cmd" }, "C")
  hs.timer.doAfter(0.1, function()
    local text = hs.pasteboard.getContents()
    if not text or text == "" then return end

    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")

    local lines = {}
    for line in text:gmatch("([^\n]*)\n?") do
      table.insert(lines, line:match("^%s*(.-)%s*$"))
    end
    text = table.concat(lines, "\n")
    text = text:gsub("^\n+", ""):gsub("\n+$", "")

    hs.pasteboard.setContents(text)
    if ctx then
      ctx.log.alert.success("Copied & trimmed")
    end
  end)
end

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  ctx.log.console.success("Clipboard feature initialized")

  return result.ok()
end

return M
