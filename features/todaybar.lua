-- TodayBar control via deep links

local M = {}

local ctx = nil

function HK_todaybarToggleExpanded()
  hs.execute("open 'todaybar://toggleExpanded'")
  ctx.log.console.log("TodayBar: toggleExpanded")
end

function HK_todaybarCyclePosition()
  hs.execute("open 'todaybar://position?edge=next'")
  ctx.log.console.log("TodayBar: cyclePosition")
end

function M.init(context)
  local result = require "core.utils.result"
  ctx = context
  ctx.log.console.success("TodayBar feature initialized")
  return result.ok()
end

return M
