-- Open YouTube links in correct Chrome profile using URLDispatcher

local M = {}

local ctx = nil

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  -- Load URLDispatcher spoon
  local success, error = pcall(function()
    hs.loadSpoon("URLDispatcher")
  end)

  if not success then
    return result.fail("DEPENDENCY_MISSING", "Failed to load URLDispatcher spoon: " .. tostring(error),
      { level = "warn" })
  end

  if not spoon.URLDispatcher then
    return result.fail("DEPENDENCY_MISSING", "URLDispatcher spoon not found after loading", { level = "warn" })
  end

  -- Configure URLDispatcher for YouTube links
  spoon.URLDispatcher.url_patterns = {
    {
      { "youtube%.com", "youtu%.be" }, -- Patterns for YouTube URLs
      function(url)
        -- Path to the Google Chrome executable
        local chromePath = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        -- Arguments for Chrome
        local args = { "--profile-directory=Default", url }

        -- Use hs.task to launch Chrome directly with the specified profile and URL.
        hs.task.new(chromePath, nil, args):start()
      end
    }
  }

  -- All other URLs will be opened by the default handler (Safari).
  spoon.URLDispatcher.default_handler = "com.google.Chrome"

  -- Start the URLDispatcher
  local startSuccess, startError = pcall(function()
    spoon.URLDispatcher:start()
  end)

  if not startSuccess then
    return result.fail("INIT_FAILED", "Failed to start URLDispatcher: " .. tostring(startError), { level = "warn" })
  end

  ctx.log.console.success("OpenYoutubeLinksInCorrectChromeProfile feature initialized")

  return result.ok()
end

return M
