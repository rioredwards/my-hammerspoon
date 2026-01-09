-- Result pattern helpers for structured error handling
-- Provides ok() and fail() functions that return consistent result tables

local result = {}

-- Create a successful result
-- @param meta Optional metadata table
-- @return Result table with ok = true
function result.ok(meta)
  return {
    ok = true,
    meta = meta or {}
  }
end

-- Create a failed result
-- @param code Error code string (e.g., "DEPENDENCY_MISSING")
-- @param msg Human-readable error message
-- @param meta Optional metadata table (can include 'level' for severity)
-- @return Result table with ok = false
function result.fail(code, msg, meta)
  meta = meta or {}
  return {
    ok = false,
    code = code,
    msg = msg,
    level = meta.level or "error",
    meta = meta
  }
end

return result
