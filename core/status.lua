-- Status tracker for feature initialization results
-- Tracks which features loaded successfully, with warnings, or failed

local status = {}

local results = {} -- Store results for each feature: { [name] = result }

-- Record a feature's initialization result
-- @param name Feature name
-- @param result Result table from feature.init()
function status.record(name, result)
  results[name] = result
end

-- Get the result for a specific feature
-- @param name Feature name
-- @return Result table or nil
function status.get(name)
  return results[name]
end

-- Get all results
-- @return Table of all results
function status.getAll()
  return results
end

-- Get summary statistics
-- @return Table with counts: { ok = n, warn = n, error = n, total = n }
function status.summary()
  local summary = {
    ok = 0,
    warn = 0,
    error = 0,
    total = 0
  }

  for _, result in pairs(results) do
    summary.total = summary.total + 1
    if result.ok then
      summary.ok = summary.ok + 1
    elseif result.level == "warn" then
      summary.warn = summary.warn + 1
    else
      summary.error = summary.error + 1
    end
  end

  return summary
end

-- Get formatted status string for display
-- @return String with summary (e.g., "✅ 8 loaded, ⚠️ 1 warning, ❌ 1 disabled")
function status.formatSummary()
  local s = status.summary()
  local parts = {}

  if s.ok > 0 then
    table.insert(parts, "✅ " .. s.ok .. " loaded")
  end
  if s.warn > 0 then
    table.insert(parts, "⚠️ " .. s.warn .. " warning" .. (s.warn > 1 and "s" or ""))
  end
  if s.error > 0 then
    table.insert(parts, "❌ " .. s.error .. " disabled")
  end

  if #parts == 0 then
    return "No features loaded"
  end

  return table.concat(parts, ", ")
end

-- Get detailed status for all features
-- @return Array of {name, status, message} tables
function status.getDetails()
  local details = {}

  for name, result in pairs(results) do
    local statusIcon
    local statusText

    if result.ok then
      statusIcon = "✅"
      statusText = "Loaded"
    elseif result.level == "warn" then
      statusIcon = "⚠️"
      statusText = "Warning"
    else
      statusIcon = "❌"
      statusText = "Disabled"
    end

    table.insert(details, {
      name = name,
      icon = statusIcon,
      status = statusText,
      message = result.msg or "",
      code = result.code
    })
  end

  -- Sort by name
  table.sort(details, function(a, b) return a.name < b.name end)

  return details
end

return status
