-- Straightaway Dashboard Feature
-- Menubar dashboard showing live status for the Straightaway app:
-- CI, Sentry (errors), Deploys, and Uptime.
--
-- Modeled on features/statusDashboard.lua for menubar syntax/conventions.
--
-- Each service is a "probe": an async HTTP request whose response is parsed
-- into a { status, detail, url } result. The menubar icon reflects the worst
-- status across all probes. Tokens are read from the macOS Keychain so no
-- secrets live in this tracked file.

local M = {}

-- ----------------------------------------------------------------------------
-- Config
-- ----------------------------------------------------------------------------
-- Endpoints/parsers are wired per service below. Replace the TODO placeholders
-- with the real endpoints once known. Auth tokens come from Keychain (see
-- keychainSecret) so nothing sensitive is committed.

local REFRESH_SECONDS = 120 -- how often to re-poll all services
local HTTP_TIMEOUT = 15 -- per-request budget hint (hs.http has no hard timeout arg)

-- Keychain service names to store tokens under (add via:
--   security add-generic-password -a "$USER" -s straightaway-github -w <token>
-- ). Read back with keychainSecret("straightaway-github").
local KEYCHAIN = {
  github = "straightaway-github",
  sentry = "straightaway-sentry",
  deploy = "straightaway-deploy",
}

local TARGETS = {
  githubRepo = "straightaway-cocktails/straight_away_app", -- GitHub Actions CI
  sentryOrg = "straightaway-yr",
  sentryProject = "python-flask",
  productionUrl = "https://straightawayapp-production.up.railway.app",
  healthPath = "/healthz", -- returns 200 {status:ok} / 503 {status:degraded}
  -- Railway deploy status (GraphQL). IDs for project "straightaway app".
  railwayProjectId = "a0b56421-2eac-48e7-b516-50d400b26d14",
  railwayServiceId = "69369984-5832-48c2-9393-ee838442fb8d", -- straight_away_app web
  railwayEnvId = "387c8ca6-0c59-4121-8aa2-47ab740648c4", -- production
}

-- ----------------------------------------------------------------------------
-- State
-- ----------------------------------------------------------------------------

local menubarItem = nil
local refreshTimer = nil
local ctxRef = nil

-- state[key] = { status = "ok"|"warn"|"error"|"unknown", detail = "...", url = "..." }
local state = {}

local STATUS_ICON = {
  ok = "✅",
  warn = "⚠️",
  error = "❌",
  unknown = "⏳",
}

-- Worst-status-wins ordering for the aggregate menubar icon.
local STATUS_RANK = { error = 3, warn = 2, unknown = 1, ok = 0 }

-- ----------------------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------------------

-- Read a secret from the macOS Keychain. Returns nil if not found.
local function keychainSecret(serviceName)
  if not serviceName then
    return nil
  end
  local cmd = string.format(
    "security find-generic-password -s %q -w 2>/dev/null",
    serviceName
  )
  local out, ok = hs.execute(cmd)
  if not ok or not out then
    return nil
  end
  out = out:gsub("%s+$", "")
  if out == "" then
    return nil
  end
  return out
end

local function log(msg)
  if ctxRef and ctxRef.log then
    ctxRef.log.console.log("[Straightaway] " .. msg)
  end
end

-- Async HTTP probe. On completion sets state[def.key] and refreshes the icon.
--   def = {
--     key, label, icon, dashboardUrl,
--     url(),                     -> request URL (string) or nil to skip
--     headers(),                 -> table of request headers (may read keychain)
--     method = "GET"|"POST",
--     body = "..."               -> optional request body
--     parse(httpStatus, body)    -> { status, detail }
--   }
local function runProbe(def)
  local url = def.url and def.url() or nil
  if not url then
    state[def.key] = { status = "unknown", detail = "not configured", url = def.dashboardUrl }
    return
  end

  local headers = (def.headers and def.headers()) or {}
  local method = def.method or "GET"

  local function onDone(httpStatus, body, _respHeaders)
    local parsed
    local ok, err = pcall(function()
      parsed = def.parse(httpStatus, body or "")
    end)
    if not ok or not parsed then
      parsed = { status = "error", detail = "parse failed: " .. tostring(err) }
    end
    state[def.key] = {
      status = parsed.status or "unknown",
      detail = parsed.detail or "",
      url = def.dashboardUrl,
    }
    M.updateMenubar()
  end

  if method == "POST" then
    hs.http.asyncPost(url, def.body or "", headers, onDone)
  else
    hs.http.asyncGet(url, headers, onDone)
  end
end

-- ----------------------------------------------------------------------------
-- Service probes
-- ----------------------------------------------------------------------------
-- Each probe returns a { status, detail } from the raw HTTP response.
-- These are the seams where real endpoints/parsers plug in.

local SERVICES = {
  -- CI: GitHub Actions latest run status for the default branch.
  {
    key = "ci",
    label = "CI",
    icon = "🔧",
    dashboardUrl = "https://github.com/" .. TARGETS.githubRepo .. "/actions",
    url = function()
      -- Private repo: an unauthenticated call 404s, so require the token.
      if not keychainSecret(KEYCHAIN.github) then
        return nil
      end
      return string.format(
        "https://api.github.com/repos/%s/actions/runs?branch=main&per_page=1",
        TARGETS.githubRepo
      )
    end,
    headers = function()
      local token = keychainSecret(KEYCHAIN.github)
      local h = { ["Accept"] = "application/vnd.github+json" }
      if token then
        h["Authorization"] = "Bearer " .. token
      end
      return h
    end,
    parse = function(httpStatus, body)
      if httpStatus ~= 200 then
        return { status = "error", detail = "HTTP " .. tostring(httpStatus) }
      end
      local data = hs.json.decode(body)
      local run = data and data.workflow_runs and data.workflow_runs[1]
      if not run then
        return { status = "unknown", detail = "no runs" }
      end
      -- conclusion: success|failure|cancelled|nil(in progress)
      local concl = run.conclusion
      local st = "warn"
      if concl == "success" then
        st = "ok"
      elseif concl == "failure" or concl == "cancelled" or concl == "timed_out" then
        st = "error"
      elseif concl == nil then
        st = "warn" -- running
      end
      return { status = st, detail = (concl or run.status or "?") .. " · " .. (run.head_branch or "") }
    end,
  },

  -- Sentry: count of unresolved issues for the project.
  {
    key = "sentry",
    label = "Sentry",
    icon = "🐞",
    dashboardUrl = string.format(
      "https://%s.sentry.io/projects/%s/",
      TARGETS.sentryOrg,
      TARGETS.sentryProject
    ),
    url = function()
      if TARGETS.sentryOrg == "ORG" or not keychainSecret(KEYCHAIN.sentry) then
        return nil
      end
      return string.format(
        "https://sentry.io/api/0/projects/%s/%s/issues/?query=is:unresolved&statsPeriod=24h",
        TARGETS.sentryOrg,
        TARGETS.sentryProject
      )
    end,
    headers = function()
      local token = keychainSecret(KEYCHAIN.sentry)
      local h = {}
      if token then
        h["Authorization"] = "Bearer " .. token
      end
      return h
    end,
    parse = function(httpStatus, body)
      if httpStatus ~= 200 then
        return { status = "error", detail = "HTTP " .. tostring(httpStatus) }
      end
      local data = hs.json.decode(body)
      local count = (type(data) == "table") and #data or 0
      local st = "ok"
      if count > 0 then
        st = "warn"
      end
      if count >= 10 then
        st = "error"
      end
      return { status = st, detail = count .. " unresolved (24h)" }
    end,
  },

  -- Deploys: latest Railway deployment state via GraphQL (no REST API).
  {
    key = "deploy",
    label = "Deploys",
    icon = "🚀",
    method = "POST",
    dashboardUrl = string.format(
      "https://railway.com/project/%s/service/%s?environmentId=%s",
      TARGETS.railwayProjectId,
      TARGETS.railwayServiceId,
      TARGETS.railwayEnvId
    ),
    url = function()
      local token = keychainSecret(KEYCHAIN.deploy)
      if not token then
        return nil -- no token yet
      end
      return "https://backboard.railway.com/graphql/v2"
    end,
    headers = function()
      local token = keychainSecret(KEYCHAIN.deploy)
      local h = { ["Content-Type"] = "application/json" }
      if token then
        h["Authorization"] = "Bearer " .. token
      end
      return h
    end,
    -- Body is static JSON; set once at definition time below via def.body.
    body = hs.json.encode({
      query = "query($input: DeploymentListInput!) { deployments(first: 1, input: $input) { edges { node { status createdAt } } } }",
      variables = {
        input = {
          projectId = TARGETS.railwayProjectId,
          serviceId = TARGETS.railwayServiceId,
          environmentId = TARGETS.railwayEnvId,
        },
      },
    }),
    parse = function(httpStatus, body)
      if httpStatus ~= 200 then
        return { status = "error", detail = "HTTP " .. tostring(httpStatus) }
      end
      local data = hs.json.decode(body)
      local edges = data and data.data and data.data.deployments and data.data.deployments.edges
      local node = edges and edges[1] and edges[1].node
      if not node then
        return { status = "unknown", detail = "no deploys" }
      end
      -- status: SUCCESS|FAILED|BUILDING|DEPLOYING|CRASHED|REMOVED|...
      local rs = node.status or "?"
      local st = "warn"
      if rs == "SUCCESS" then
        st = "ok"
      elseif rs == "FAILED" or rs == "CRASHED" then
        st = "error"
      elseif rs == "BUILDING" or rs == "DEPLOYING" or rs == "INITIALIZING" or rs == "QUEUED" then
        st = "warn"
      end
      return { status = st, detail = rs }
    end,
  },

  -- Uptime: hit the production health endpoint; 2xx = up.
  {
    key = "uptime",
    label = "Uptime",
    icon = "📡",
    dashboardUrl = TARGETS.productionUrl,
    url = function()
      if TARGETS.productionUrl == "https://example.com" then
        return nil
      end
      return TARGETS.productionUrl .. TARGETS.healthPath
    end,
    headers = function()
      return {}
    end,
    parse = function(httpStatus, body)
      if httpStatus >= 200 and httpStatus < 300 then
        return { status = "ok", detail = "up (HTTP " .. httpStatus .. ")" }
      end
      return { status = "error", detail = "down (HTTP " .. tostring(httpStatus) .. ")" }
    end,
  },
}

local SERVICE_BY_KEY = {}
for _, def in ipairs(SERVICES) do
  SERVICE_BY_KEY[def.key] = def
end

-- ----------------------------------------------------------------------------
-- Refresh + rendering
-- ----------------------------------------------------------------------------

function M.refreshAll()
  log("refreshing all probes")
  for _, def in ipairs(SERVICES) do
    -- mark in-flight only if we have nothing yet
    if not state[def.key] then
      state[def.key] = { status = "unknown", detail = "loading…", url = def.dashboardUrl }
    end
    runProbe(def)
  end
  M.updateMenubar()
end

-- Compute the aggregate (worst) status across all services.
local function aggregateStatus()
  local worst = "ok"
  local anyKnown = false
  for _, def in ipairs(SERVICES) do
    local s = state[def.key]
    if s then
      anyKnown = true
      if (STATUS_RANK[s.status] or 0) > (STATUS_RANK[worst] or 0) then
        worst = s.status
      end
    end
  end
  if not anyKnown then
    return "unknown"
  end
  return worst
end

function M.updateMenubar()
  if not menubarItem then
    return
  end
  local agg = aggregateStatus()
  menubarItem:setTitle((STATUS_ICON[agg] or "⏳") .. " SA")
end

local function buildMenu()
  local menu = {}

  table.insert(menu, { title = "Straightaway Status", disabled = true })
  table.insert(menu, { title = "-" })

  for _, def in ipairs(SERVICES) do
    local s = state[def.key] or { status = "unknown", detail = "loading…" }
    local icon = STATUS_ICON[s.status] or "⏳"
    local title = string.format("%s  %s %s — %s", icon, def.icon, def.label, s.detail or "")
    local url = s.url or def.dashboardUrl
    table.insert(menu, {
      title = title,
      fn = function()
        if url then
          hs.urlevent.openURL(url)
        end
      end,
    })
  end

  table.insert(menu, { title = "-" })
  table.insert(menu, {
    title = "Refresh now",
    fn = function()
      M.refreshAll()
    end,
  })

  return menu
end

-- ----------------------------------------------------------------------------
-- Lifecycle
-- ----------------------------------------------------------------------------

function M.init(ctx)
  local result = require "core.utils.result"
  ctxRef = ctx

  menubarItem = hs.menubar.new()
  if not menubarItem then
    return result.fail("INIT_FAILED", "Failed to create menubar item")
  end

  menubarItem:setTitle("⏳ SA")
  menubarItem:setMenu(buildMenu)

  -- Initial fetch shortly after load, then poll on an interval.
  hs.timer.doAfter(2, function()
    M.refreshAll()
  end)
  refreshTimer = hs.timer.doEvery(REFRESH_SECONDS, function()
    M.refreshAll()
  end)

  ctx.log.console.success("Straightaway Dashboard feature initialized")
  return result.ok()
end

return M
