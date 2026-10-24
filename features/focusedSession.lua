-- Focused agent session: which Claude Code or Codex chat is on screen right now.
-- Writes it to a state file any tool can read (FOCUSED_SESSION_FILE), and (DEBUG)
-- shows it as a persistent alert at the bottom of the screen. Toggle off from the
-- status menu.
--
-- State file: the last agent session that was in front, kept when focus moves to
-- another app (so a picker that steals focus still knows it):
--   { v = 1, agent = "claude" | "codex", session = id, title, frontmost = true when that session's app is still in front,
--     focused_at = when it became the focused session, updated_at }
-- Keys are absent when unknown (no agent session seen yet, or no Codex thread
-- matched the window title).
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
local statePath = nil
local last = nil -- { agent, session, title, focusedAt }
local writtenKey = nil

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

-- Codex thread id for a window title (the thread's name). Names can repeat, so
-- the most recently updated live thread wins.
local function codexThreadId(name)
  local db = hs.sqlite3.open((ctx.constants.CODEX_STATE_DB:gsub("^~", os.getenv("HOME"))), hs.sqlite3.OPEN_READONLY)
  if not db then
    ctx.log.console.warn("focusedSession: cannot open Codex state db")
    return nil
  end
  local st = db:prepare("select id from threads where name = ? and archived = 0 order by updated_at_ms desc limit 1")
  local id = nil
  if st then
    st:bind_values(name)
    for row in st:nrows() do
      id = row.id
    end
    st:finalize()
  end
  db:close()
  return id
end

local function shortId(id)
  return id and (" [" .. id:sub(1, 8) .. "]") or ""
end

-- Returns the focused session ({ agent, session, title }) or nil, plus the app name.
local function currentFocus()
  local app = hs.application.frontmostApplication()
  local appName = app and app:name() or "?"

  if appName == "Claude" then
    local s = mostRecentClaudeSession()
    if s then
      return { agent = "claude", session = s.session, title = s.title }, appName
    end
  elseif appName == "ChatGPT" then
    local win = app:focusedWindow()
    local title = win and win:title() or ""
    if title ~= "" then
      return { agent = "codex", session = codexThreadId(title), title = title }, appName
    end
  end

  return nil, appName
end

local function iso(t)
  return os.date("!%Y-%m-%dT%H:%M:%SZ", t)
end

local function writeState(frontmost)
  local now = os.time()
  local state = {
    v = 1,
    agent = last and last.agent,
    session = last and last.session,
    title = last and last.title,
    frontmost = frontmost,
    focused_at = last and iso(last.focusedAt),
    updated_at = iso(now),
  }
  local tmp = statePath .. ".tmp"
  local f = assert(io.open(tmp, "w"))
  f:write(hs.json.encode(state))
  f:close()
  assert(os.rename(tmp, statePath))
end

local function refresh()
  local focus, appName = currentFocus()
  if focus then
    local same = last and last.agent == focus.agent
      and (focus.session and focus.session == last.session or (not focus.session and focus.title == last.title))
    focus.focusedAt = same and last.focusedAt or os.time()
    last = focus
  end
  local frontmost = focus ~= nil
  local key = last and table.concat({ last.agent, tostring(last.session), tostring(last.title), tostring(frontmost) }, "|")
    or tostring(frontmost)
  if key ~= writtenKey then
    writtenKey = key
    writeState(frontmost)
  end

  local text
  if focus then
    text = (focus.agent == "claude" and "Claude · " or "Codex · ") .. (focus.title or "(untitled)") .. shortId(focus.session)
  else
    text = "No agent session (" .. appName .. ")"
  end
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

  statePath = ctx.constants.FOCUSED_SESSION_FILE:gsub("^~", os.getenv("HOME"))
  hs.fs.mkdir(statePath:match("^(.*)/[^/]+$"))

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
