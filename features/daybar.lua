-- DayBar control via deep links

local M = {}

local ctx = nil

function HK_daybarToggleExpanded()
  hs.execute("open 'daybar://toggleExpanded'")
  ctx.log.console.log("DayBar: toggleExpanded")
end

function HK_daybarCyclePosition()
  hs.execute("open 'daybar://position?edge=next'")
  ctx.log.console.log("DayBar: cyclePosition")
end

function M.init(context)
  local result = require "core.utils.result"
  ctx = context
  ctx.log.console.success("DayBar feature initialized")
  return result.ok()
end

return M
