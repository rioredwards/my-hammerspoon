-- Agent-audio web view: transcript + audio player for one recording in a
-- lightweight WKWebView window — no browser switch, and unlike Quick Look's
-- HTML sandbox both the audio element and JS (speed pills) actually work.
--
-- Opened by the Raycast play-agent-audio extension via:
--   hammerspoon://agent-audio-webview?file=/path/to/page.html
--
-- This is a param-carrying deeplink, so it binds hs.urlevent directly in
-- init() instead of going through the jsonc hotkey loader (the loader's
-- deeplink wrapper drops URL params by design).
local M = {}

local ctx = nil
local webview = nil

local function showAgentAudioWebview(file)
  if not file or file == "" then
    ctx.log.all.warn("agent-audio-webview: missing file param")
    return
  end

  local screen = hs.screen.mainScreen()
  local frame = screen:frame()
  local width = math.min(760, frame.w * 0.55)
  local height = frame.h * 0.7
  local rect = hs.geometry.rect(frame.x + (frame.w - width) / 2, frame.y + (frame.h - height) / 2, width, height)

  if webview then
    webview:delete()
    webview = nil
  end

  webview = hs.webview.newBrowser(rect)
      :windowStyle(hs.webview.windowMasks.titled | hs.webview.windowMasks.closable | hs.webview.windowMasks.resizable |
        hs.webview.windowMasks.miniaturizable)
      :closeOnEscape(true)
      :deleteOnClose(true)
      -- Without this the window never receives keyboard events, which kills
      -- the page's Space/arrow shortcuts and the autofocused play button.
      :allowTextEntry(true)
      :windowTitle("Agent Audio")
      :url("file://" .. file:gsub(" ", "%%20"))

  webview:windowCallback(function(action)
    if action == "closing" then
      webview = nil
    end
  end)

  webview:show()
  webview:bringToFront()
end

function M.init(context)
  local result = require "core.utils.result"
  ctx = context

  hs.urlevent.bind("agent-audio-webview", function(_, params)
    showAgentAudioWebview(params and params.file)
  end)

  ctx.log.console.success("AgentAudioWebview feature initialized")
  return result.ok()
end

return M
