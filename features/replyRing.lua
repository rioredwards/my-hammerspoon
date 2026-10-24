-- Reply ring: one Logi Actions Ring bubble per reply category. A bubble opens
--   hammerspoon://reply-option?category=accept
-- which copies the top chat's first option in that category (the same chat the
-- Reply Options picker lists first: the one on screen, else the last focused)
-- and shows what was copied. Engine contract: ~/scripts/reply-options.md

local M = {}

local ctx = nil

local CLI = os.getenv("HOME") .. "/scripts/reply-options"
local CATEGORIES = {
  accept = true, reject = true, explain = true, redirect = true,
  clarify = true, narrow = true, defer = true, verify = true,
}

local function show(text)
  hs.alert.show(text, ctx.constants.REPLY_RING_ALERT_STYLE, nil, ctx.constants.REPLY_RING_ALERT_SECONDS)
end

local function pick(category, stdout)
  local sessions = hs.json.decode(stdout)
  local chat = sessions and sessions[1]
  if not chat then
    show("No chat is waiting on you")
    return
  end
  local title = chat.title or chat.agent
  for _, o in ipairs(chat.options or {}) do
    if o.category == category then
      hs.pasteboard.setContents(o.text)
      show("Copied " .. category .. " · " .. o.label .. "\n" .. title .. "\n\n" .. o.text)
      return
    end
  end
  local have = {}
  for _, o in ipairs(chat.options or {}) do
    have[#have + 1] = o.category
  end
  show("No " .. category .. " option for " .. title
    .. (#have > 0 and ("\nHas: " .. table.concat(have, ", ")) or ("\n" .. (chat.skip_reason or chat.error or chat.status))))
end

local function replyOption(category)
  if not CATEGORIES[category] then
    show("Reply ring: unknown category '" .. tostring(category) .. "'")
    ctx.log.console.error("replyRing: unknown category " .. tostring(category))
    return
  end
  local task = hs.task.new(CLI, function(code, stdout, stderr)
    if code ~= 0 then
      show("reply-options failed: " .. stderr)
      ctx.log.console.error("replyRing: " .. stderr)
      return
    end
    pick(category, stdout)
  end, { "get", "--recent", "1" })
  task:setEnvironment({ HOME = os.getenv("HOME"), PATH = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin" })
  task:start()
end

function M.init(context)
  local result = require "core.utils.result"
  ctx = context

  hs.urlevent.bind("reply-option", function(_, params)
    replyOption(params and params.category)
  end)

  ctx.log.console.success("ReplyRing feature initialized")
  return result.ok()
end

return M
