-- Raycast deep link URLs for window management

local M = {}

local ctx = nil

function HK_searchDirectories()
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/mrpunkin/raycast-zoxide/search-directories")
  end
end

function HK_searchFiles() 
  ctx.log.all.log("Search feature initialized")
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/file-search/search-files")
  end
end

function HK_searchEmojiSymbols() 
  ctx.log.all.log("Search feature initialized")
  if ctx then
    ctx.utils.openDeepLinkWithoutFocusingApp("raycast://extensions/raycast/emoji-symbols/search-emoji-symbols")
  end
end

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  -- All HK_ functions are already exported to global scope
  ctx.log.console.success("Search feature initialized")

  return result.ok()
end

return M
