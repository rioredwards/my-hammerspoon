-- Ensure local server is running
-- Checks if server is running on configured port, starts it if not

local M = {}

local ctx = nil

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  -- Check if port is configured
  if not ctx.constants.LOCAL_SERVER_PORT then
    return result.fail("CONFIG_ERROR", "LOCAL_SERVER_PORT not found in constants", { level = "warn" })
  end

  ctx.log.console.success("EnsureLocalServer feature initialized")

  return result.ok()
end

return M
