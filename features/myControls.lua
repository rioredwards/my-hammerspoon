-- My Controls HUD toggle via deep link

local M = {}

local ctx = nil

function HK_myControlsToggle()
  -- Dev (`npm run dev`) and the packaged build register different URL schemes so
  -- they don't fight over one Launch Services handler (a dev hotkey hitting a
  -- stale build). Try dev first; if no app claims it, fall back to packaged.
  -- Whichever instance is alive wins.
  local _, ok = hs.execute("open 'mycontrols-dev://window/toggle' 2>/dev/null")
  if not ok then
    hs.execute("open 'mycontrols://window/toggle'")
  end
  ctx.log.console.log("My Controls: toggle")
end

function M.init(context)
  local result = require "core.utils.result"
  ctx = context
  ctx.log.console.success("My Controls feature initialized")
  return result.ok()
end

return M
