-- Focused agent session: which Claude Code or Codex chat is on screen right now.
-- DEBUG: shows it as a persistent alert at the bottom of the screen and updates
-- it whenever focus moves. Toggle off from the status menu when done.
--
-- Claude desktop: the window title is always "Claude", so the session comes from
-- the app's own session store, where `lastFocusedAt` is bumped each time a
-- session is switched into. Codex (inside ChatGPT.app): the window title is the
-- thread name.

local M = {}

local ctx = nil
local appWatcher = nil
local storeWatcher = nil
local chatgptFilter = nil
local alertId = nil
local shownText = nil

-- path -> { focusedAt, title, session }
local claudeSessions = {}

local function readSessionFile(path)
  local ok, data = pcall(hs.json.read, path)
  if not ok or type(data) ~= "table" then
    claudeSessions[path] = nil
    return
  end
  claudeSessions[path] = {
    focusedAt = tonumber(data.lastFocusedAt) or 0,
    title = data.title,
    session = data.cliSessionId,
  }
end

local function isSessionFile(path)
  return path:match("/local_[^/]+%.json$") ~= nil
end

-- Startup scan: only files touched recently, since focusing a session rewrites its file.
local function scanRecent(root, maxAgeSeconds)
  local cutoff = os.time() - maxAgeSeconds
  local function walk(dir, depth)
    for name in hs.fs.dir(dir) do
      if name ~= "." and name ~= ".." then
        local path = dir .. "/" .. name
        local attrs = hs.fs.attributes(path)
        if attrs and attrs.mode == "directory" and depth < 2 then
          walk(path, depth + 1)
        elseif attrs and attrs.mode == "file" and isSessionFile(path) and attrs.modification >= cutoff then
          readSessionFile(path)
        end
      end
    end
  end
  walk(root, 0)
end

local function mostRecentClaudeSession()
  local best = nil
  for _, s in pairs(claudeSessions) do
    if not best or s.focusedAt > best.focusedAt then
      best = s
    end
  end
  return best
end

local function shortId(id)
  return id and (" [" .. id:sub(1, 8) .. "]") or ""
end

local function describeFocus()
  local app = hs.application.frontmostApplication()
  local appName = app and app:name() or "?"

  if appName == "Claude" then
    local s = mostRecentClaudeSession()
    if not s then
      return "Claude · no Code session found"
    end
    return "Claude · " .. (s.title or "(untitled)") .. shortId(s.session)
  end

  if appName == "ChatGPT" then
    local win = app:focusedWindow()
    local title = win and win:title() or ""
    return "Codex · " .. (title ~= "" and title or "(no window title)")
  end

  return "No agent session (" .. appName .. ")"
end

local function refresh()
  local text = describeFocus()
  if text == shownText then
    return
  end
  shownText = text
  if alertId then
    hs.alert.closeSpecific(alertId, 0)
  end
  alertId = hs.alert.show(text, ctx.constants.FOCUSED_SESSION_ALERT_STYLE, nil, true)
end

function M.init(context)
  local result = require "core.utils.result"
  ctx = context

  local root = ctx.constants.CLAUDE_SESSIONS_DIR:gsub("^~", os.getenv("HOME"))
  if not hs.fs.attributes(root) then
    return result.fail("STORE_MISSING", "Claude session store not found: " .. root, { level = "warn" })
  end

  scanRecent(root, ctx.constants.FOCUSED_SESSION_SCAN_DAYS * 86400)

  storeWatcher = hs.pathwatcher.new(root, function(paths)
    for _, path in ipairs(paths) do
      if isSessionFile(path) then
        readSessionFile(path)
      end
    end
    refresh()
  end):start()

  appWatcher = hs.application.watcher.new(function(_, event)
    if event == hs.application.watcher.activated then
      refresh()
    end
  end):start()

  chatgptFilter = hs.window.filter.new(false):setAppFilter("ChatGPT", {})
  chatgptFilter:subscribe({
    hs.window.filter.windowTitleChanged,
    hs.window.filter.windowFocused,
  }, refresh)

  refresh()
  return result.ok()
end

return M
