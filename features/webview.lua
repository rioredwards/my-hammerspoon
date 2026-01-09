-- Webview display function with graceful degradation
local M = {}

local ctx = nil
local webviewObject = nil
local hotkeyReferenceWebview = nil
local hotkeyReferenceUserContent = nil
local genericWebviewUserContent = nil

-- Create offline UI HTML
local function createOfflineUI(devPort, prodPort, retryUrl)
  return string.format([[
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Server Offline</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
      background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%);
      color: white;
      text-align: center;
      padding: 20px;
    }
    .container {
      max-width: 500px;
    }
    h1 {
      font-size: 2.5em;
      margin-bottom: 0.5em;
    }
    p {
      font-size: 1.2em;
      margin-bottom: 1.5em;
      opacity: 0.9;
    }
    .ports {
      background: rgba(255, 255, 255, 0.1);
      padding: 15px;
      border-radius: 8px;
      margin: 20px 0;
    }
    button {
      background: white;
      color: #667eea;
      border: none;
      padding: 15px 30px;
      font-size: 1.1em;
      border-radius: 8px;
      cursor: pointer;
      font-weight: bold;
      transition: transform 0.2s;
    }
    button:hover {
      transform: scale(1.05);
    }
    button:active {
      transform: scale(0.95);
    }
    .instructions {
      margin-top: 30px;
      font-size: 0.9em;
      opacity: 0.8;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>🔌 Server Offline</h1>
    <p>The local development server is not running.</p>
    <div class="ports">
      <strong>Expected ports:</strong><br>
      Dev: %s<br>
      Prod: %s
    </div>
    <div style="display: flex; gap: 15px; justify-content: center; margin-top: 20px;">
      <button onclick="startServer()">🚀 Start Server</button>
      <button onclick="window.location.reload()">🔄 Retry</button>
    </div>
    <div class="instructions">
      <p>To start the server, run:</p>
      <code style="background: rgba(0,0,0,0.2); padding: 5px 10px; border-radius: 4px;">start-local-server</code>
      <p style="margin-top: 15px;">Or press <kbd style="background: rgba(0,0,0,0.2); padding: 3px 8px; border-radius: 3px;">R</kbd> to retry</p>
    </div>
  </div>
  <script>
    function startServer() {
      if (window.sendMessageToHammerspoon) {
        window.sendMessageToHammerspoon({ type: 'startServer' });
      } else {
        console.error('Hammerspoon communication not available');
      }
    }

    document.addEventListener('keydown', function(e) {
      if (e.key === 'r' || e.key === 'R') {
        window.location.reload();
      }
    });
  </script>
</body>
</html>
]], devPort or "N/A", prodPort or "N/A")
end

-- Create user content controller with message handling
local function createUserContentController(handlerName)
  local userContent = hs.webview.usercontent.new(handlerName)

  -- Inject JavaScript to enable communication from webview to Hammerspoon
  userContent:injectScript({
    source = string.format([[
      (function() {
        // Expose function to send messages to Hammerspoon
        window.sendMessageToHammerspoon = function(message) {
          try {
            if (typeof message === 'object') {
              webkit.messageHandlers.%s.postMessage(JSON.stringify(message));
            } else {
              webkit.messageHandlers.%s.postMessage(message);
            }
          } catch(err) {
            console.error('Failed to send message to Hammerspoon:', err);
          }
        };

        // Listen for messages from Hammerspoon
        window.addEventListener('hammerspoonMessage', function(event) {
          if (window.onHammerspoonMessage && typeof window.onHammerspoonMessage === 'function') {
            window.onHammerspoonMessage(event.detail);
          }
        });

        // Notify that communication is ready
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', function() {
            if (window.onHammerspoonReady && typeof window.onHammerspoonReady === 'function') {
              window.onHammerspoonReady();
            }
          });
        } else {
          if (window.onHammerspoonReady && typeof window.onHammerspoonReady === 'function') {
            window.onHammerspoonReady();
          }
        }
      })();
    ]], handlerName, handlerName),
    mainFrame = true,
    injectionTime = "documentStart"
  })

  -- Set up callback to handle messages from JavaScript
  userContent:setCallback(function(message)
    if ctx then
      ctx.log.console.log("Received message from webview: " .. hs.inspect(message))
    end

    if type(message) ~= "table" then
      ctx.log.all.warn("message is not table")
      return
    end

    if not message.body then
      ctx.log.all.warn("message is table but no body")
      return
    end

    if type(message.body) ~= "string" then
      ctx.log.all.warn("body is not string")
      return
    end

    -- Try to parse as JSON, fallback to string
    local parsedMessageBody = message.body
    local success, result = pcall(function()
      return hs.json.decode(parsedMessageBody)
    end)
    if success and result then
      parsedMessageBody = result
    end

    if not parsedMessageBody.type then
      ctx.log.all.warn("body is table but no type")
      return
    end

    if type(parsedMessageBody.type) ~= "string" then
      ctx.log.all.warn("type is not string")
      return
    end

    if parsedMessageBody.type == "startServer" then
      -- Close the webview
      if hotkeyReferenceWebview then
        hotkeyReferenceWebview:delete()
        hotkeyReferenceWebview = nil
      end
      if hotkeyReferenceUserContent then
        hotkeyReferenceUserContent = nil
      end

      -- Open Terminal application
      local success = hs.application.launchOrFocus("iTerm")
      if success then
        ctx.log.console.success("Opened iTerm for server startup")
        -- copy the start-local-server command to the clipboard
        hs.pasteboard.setContents("start-local-server")
        -- alert the user that the command has been copied to the clipboard
        ctx.log.all.success("Paste the command into iTerm to start the server.", 6)
      else
        ctx.log.all.warn("Failed to open iTerm")
      end
    end
  end)

  return userContent
end

-- Send message from Hammerspoon to JavaScript in webview
local function sendMessageToWebview(webview, message)
  if not webview then
    if ctx then
      ctx.log.all.warn("Cannot send message: webview is nil")
    end
    return false
  end

  -- Convert message to JSON if it's a table
  local messageStr = message
  if type(message) == "table" then
    local success, jsonStr = pcall(function()
      return hs.json.encode(message)
    end)
    if success then
      messageStr = jsonStr
    else
      if ctx then
        ctx.log.all.warn("Failed to encode message to JSON")
      end
      return false
    end
  end

  -- Send message via JavaScript event
  local jsCode = string.format([[
    (function() {
      var event = new CustomEvent('hammerspoonMessage', { detail: %s });
      window.dispatchEvent(event);
    })();
  ]], messageStr)

  webview:evaluateJavaScript(jsCode, function(result, error)
    if error then
      if ctx then
        ctx.log.all.warn("Failed to send message to webview: " .. tostring(error))
      end
    end
  end)

  return true
end

-- Test if a URL is actually reachable
local function testUrl(url)
  if not url then
    return false
  end
  -- Try a quick HEAD request with a short timeout
  local status, body, headers = hs.http.get(url, nil, 1.0) -- 1 second timeout
  return status == 200
end

-- Get webview URL, checking both dev and prod ports
local function getWebviewUrl()
  local devPort = ctx.constants.LOCAL_DEV_SERVER_PORT
  local prodPort = ctx.constants.LOCAL_SERVER_PORT

  ctx.log.console.log("Getting webview URL. Ports: LOCAL_SERVER_PORT=" ..
    tostring(prodPort) .. ", LOCAL_DEV_SERVER_PORT=" .. tostring(devPort))

  ctx.log.console.log("Parsed ports: devPort=" .. tostring(devPort) .. ", prodPort=" .. tostring(prodPort))

  local htmlUrlDev = devPort and string.format("http://localhost:%d/hotkey-ref-webview/", devPort) or nil
  local htmlUrlProd = prodPort and string.format("http://localhost:%d/hotkey-ref-webview/", prodPort) or nil

  -- Try dev URL first (test if it's actually reachable)
  if htmlUrlDev then
    ctx.log.console.log("Testing dev URL: " .. htmlUrlDev)
    if testUrl(htmlUrlDev) then
      ctx.log.console.success("Dev URL is reachable!")
      return htmlUrlDev, "dev", devPort, prodPort
    end
  end

  -- Try prod URL
  if htmlUrlProd then
    ctx.log.console.log("Testing prod URL: " .. htmlUrlProd)
    if testUrl(htmlUrlProd) then
      ctx.log.console.success("Prod URL is reachable!")
      return htmlUrlProd, "prod", devPort, prodPort
    else
      ctx.log.console.warn("Prod URL not reachable")
    end
  end

  -- Neither URL is reachable
  ctx.log.console.warn("Neither dev nor prod URL is reachable")
  return nil, nil, devPort, prodPort
end

-- Display hotkey reference from web server with graceful degradation
local function showHotkeyReferenceFromJson()
  local htmlUrl, environment, devPort, prodPort = getWebviewUrl()

  -- Get screen dimensions for centering
  local screen = hs.screen.mainScreen()
  local screenFrame = screen:frame()
  local width = screenFrame.w * ctx.constants.WEBVIEW_WIDTH_PERCENT
  local height = screenFrame.h * ctx.constants.WEBVIEW_HEIGHT_PERCENT
  local x = screenFrame.x + (screenFrame.w - width) / 2
  local y = screenFrame.y + (screenFrame.h - height) / 2
  local rect = hs.geometry.rect(x, y, width, height)

  -- Always delete and recreate webview to clear cache
  -- This ensures fresh data is loaded, including any AJAX/fetch requests
  if hotkeyReferenceWebview then
    hotkeyReferenceWebview:delete()
    hotkeyReferenceWebview = nil
  end
  if hotkeyReferenceUserContent then
    hotkeyReferenceUserContent = nil
  end

  -- Create user content controller for communication
  hotkeyReferenceUserContent = createUserContentController("hotkeyReferenceHandler")

  -- Create fresh webview (clears all cache) with user content controller
  hotkeyReferenceWebview = hs.webview.newBrowser(rect, { developerExtrasEnabled = true, privateBrowsing = true },
        hotkeyReferenceUserContent)
      :allowTextEntry(true)
      :windowStyle(hs.webview.windowMasks.titled | hs.webview.windowMasks.closable | hs.webview.windowMasks.resizable |
        hs.webview.windowMasks.miniaturizable | hs.webview.windowMasks.nonactivating)
      :deleteOnClose(true)
      :windowTitle("Hotkey Reference")
      :transparent(false)

  -- Handle window close event
  hotkeyReferenceWebview:windowCallback(function(action, webview)
    if action == "closing" then
      hotkeyReferenceWebview = nil
    end
  end)

  if not htmlUrl then
    ctx.log.all.warn("Server offline, showing offline UI")
    -- hotkeyReferenceWebview:html(offlineHTML)
    local offlineHTML = createOfflineUI(devPort, prodPort)
    hotkeyReferenceWebview:html(offlineHTML)
  else
    -- Get currently active application for context
    local activeApp = hs.application.frontmostApplication()
    local appName = nil
    if activeApp then
      appName = activeApp:name()
      appName = hs.http.encodeForQuery(appName)
    end
    -- Add app name as query parameter if available
    if appName then
      local separator = string.find(htmlUrl, "?") and "&" or "?"
      htmlUrl = htmlUrl .. separator .. "app=" .. appName
    end
    ctx.log.console.log("Loading webview from: " .. htmlUrl)
    hotkeyReferenceWebview:url(htmlUrl)
  end


  hotkeyReferenceWebview:show()
  hotkeyReferenceWebview:bringToFront()
end

local function closeHotkeyReference()
  if hotkeyReferenceWebview then
    hotkeyReferenceWebview:delete()
    hotkeyReferenceWebview = nil
  end
  if hotkeyReferenceUserContent then
    hotkeyReferenceUserContent = nil
  end
end

-- Generic webview function (kept for backward compatibility)
local function showWebview()
  local url = ctx.constants.WEBVIEW_GENERIC_URL

  local screen = hs.screen.mainScreen()
  local screenFrame = screen:frame()
  local width = screenFrame.w * ctx.constants.WEBVIEW_GENERIC_WIDTH_PERCENT
  local height = screenFrame.h * ctx.constants.WEBVIEW_GENERIC_HEIGHT_PERCENT
  local x = screenFrame.x + (screenFrame.w - width) / 2
  local y = screenFrame.y + (screenFrame.h - height) / 2
  local rect = hs.geometry.rect(x, y, width, height)

  if not webviewObject then
    -- Create user content controller for communication
    genericWebviewUserContent = createUserContentController("genericWebviewHandler")

    webviewObject = hs.webview.newBrowser(rect, nil, genericWebviewUserContent)
        :allowTextEntry(true)
        :closeOnEscape(true)
        :deleteOnClose(true)
        :windowStyle(hs.webview.windowMasks.titled | hs.webview.windowMasks.closable | hs.webview.windowMasks.resizable |
          hs.webview.windowMasks.miniaturizable)

    webviewObject:windowCallback(function(action, webview)
      if action == "closing" then
        ctx.log.all.log("Webview closed")
        webviewObject = nil
        genericWebviewUserContent = nil
      end
    end)
  end

  webviewObject:url(url)
  webviewObject:show()
  webviewObject:bringToFront()
end

local function closeWebview()
  if webviewObject then
    ctx.log.all.log("Closing webview")
    webviewObject:delete()
    webviewObject = nil
  end
  if genericWebviewUserContent then
    genericWebviewUserContent = nil
  end
end

-- Export hotkey functions to global scope (needed for hotkey system)
function HK_toggleHotkeyReference()
  if hotkeyReferenceWebview and hotkeyReferenceWebview:isVisible() then
    closeHotkeyReference()
  else
    showHotkeyReferenceFromJson()
  end
end

function HK_toggleWebview()
  ctx.log.all.log("Toggling webview")
  if webviewObject and webviewObject:isVisible() then
    closeWebview()
  else
    showWebview()
  end
end

-- Public API: Send message to hotkey reference webview
function M.sendMessageToHotkeyReference(message)
  return sendMessageToWebview(hotkeyReferenceWebview, message)
end

-- Public API: Send message to generic webview
function M.sendMessageToGenericWebview(message)
  return sendMessageToWebview(webviewObject, message)
end

-- Public API: Set custom message handler
-- This function will be called when messages are received from JavaScript
-- handler(message, handlerName) where message is the parsed message and handlerName identifies which webview
function M.setMessageHandler(handler)
  M.onMessage = handler
end

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  -- Check if we have at least one port configured
  if not ctx.constants.LOCAL_SERVER_PORT and not ctx.constants.LOCAL_DEV_SERVER_PORT then
    return result.fail("CONFIG_ERROR", "No server ports configured (LOCAL_SERVER_PORT or LOCAL_DEV_SERVER_PORT)",
      { level = "warn" })
  end

  -- Feature initializes successfully even if server is down
  -- Graceful degradation happens when opening the webview
  ctx.log.console.success("Webview feature initialized (will degrade gracefully if server offline)")

  return result.ok()
end

return M
