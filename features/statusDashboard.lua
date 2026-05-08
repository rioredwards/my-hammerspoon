-- Status Dashboard Feature
-- Displays feature status in the menubar

local M = {}

local menubarItem = nil

local function buildFeatureToggleItem(ctx, feature, statusByName)
  local featureState = ctx.features
  local enabled = true
  if featureState and featureState.isEnabled then
    enabled = featureState.isEnabled(feature.name)
  end

  local locked = feature.locked == true
  if featureState and featureState.isLocked then
    locked = locked or featureState.isLocked(feature.name)
  end

  if locked then
    enabled = true
  end

  local detail = statusByName[feature.name]
  local title = feature.name

  if locked then
    title = title .. " (locked)"
  elseif detail and detail.status == "Disabled" then
    title = title .. " (off)"
  end

  local item = {
    title = title,
    checked = enabled,
    disabled = locked
  }

  if not locked then
    item.fn = function()
      if not ctx.features or not ctx.features.setEnabled then
        return
      end

      ctx.features.setEnabled(feature.name, not enabled)
      ctx.log.console.log(string.format("Feature '%s' toggled to %s", feature.name, not enabled and "off" or "on"))
      hs.timer.doAfter(0.05, hs.reload)
    end
  end

  return item
end

-- Create offline HTML for webview status display
local function createStatusHTML(details)
  local html = [[
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Hammerspoon Status</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      padding: 20px;
      background: #1a1a1a;
      color: #e0e0e0;
      margin: 0;
    }
    h1 {
      margin-top: 0;
      color: #fff;
    }
    .feature {
      padding: 10px;
      margin: 5px 0;
      border-radius: 5px;
      background: #2a2a2a;
    }
    .feature.ok {
      border-left: 3px solid #4caf50;
    }
    .feature.warn {
      border-left: 3px solid #ff9800;
    }
    .feature.error {
      border-left: 3px solid #f44336;
    }
    .feature.disabled {
      border-left: 3px solid #9e9e9e;
    }
    .feature-name {
      font-weight: bold;
      margin-bottom: 5px;
    }
    .feature-message {
      font-size: 0.9em;
      color: #aaa;
    }
    .summary {
      margin-bottom: 20px;
      padding: 15px;
      background: #2a2a2a;
      border-radius: 5px;
    }
  </style>
</head>
<body>
  <h1>Hammerspoon Status</h1>
  <div class="summary">
    <strong>]] .. (details.summary or "Loading...") .. [[</strong>
  </div>
]]

  for _, feature in ipairs(details.features or {}) do
    html = html .. string.format([[
  <div class="feature %s">
    <div class="feature-name">%s %s</div>
    <div class="feature-message">%s</div>
  </div>
]], feature.statusClass or feature.status, feature.icon, feature.name, feature.message or "")
  end

  html = html .. [[
</body>
</html>
]]

  return html
end

-- Update menubar item
local function updateMenubar(ctx)
  if not menubarItem then
    return
  end

  local summary = ctx.status.formatSummary()
  local summaryDetails = ctx.status.summary()

  -- Choose icon based on status
  local icon = "✅"
  if summaryDetails.error > 0 then
    icon = "❌"
  elseif summaryDetails.warn > 0 then
    icon = "⚠️"
  elseif summaryDetails.disabled > 0 then
    icon = "⏸️"
  end

  menubarItem:setTitle(icon .. " " .. summaryDetails.total)
end

-- Show detailed status in webview
local function showDetailedStatus(ctx)
  local details = ctx.status.getDetails()
  local summary = ctx.status.formatSummary()

  local screen = hs.screen.mainScreen()
  local screenFrame = screen:frame()
  local width = screenFrame.w * 0.6
  local height = screenFrame.h * 0.7
  local x = screenFrame.x + (screenFrame.w - width) / 2
  local y = screenFrame.y + (screenFrame.h - height) / 2
  local rect = hs.geometry.rect(x, y, width, height)

  local webview = hs.webview.newBrowser(rect)
      :allowTextEntry(true)
      :windowStyle(hs.webview.windowMasks.closable | hs.webview.windowMasks.titled)
      :deleteOnClose(true)
      :windowTitle("Hammerspoon Status")

  local html = createStatusHTML({
    summary = summary,
    features = details
  })

  webview:html(html)
  webview:show()
  webview:bringToFront()
end

function M.init(ctx)
  local result = require "core.utils.result"

  -- Create menubar item
  menubarItem = hs.menubar.new()
  if not menubarItem then
    return result.fail("INIT_FAILED", "Failed to create menubar item")
  end

  -- Set initial title
  updateMenubar(ctx)

  -- Create menu
  menubarItem:setMenu(function()
    local menu = {}
    local details = ctx.status.getDetails()
    local detailsByName = {}

    for _, feature in ipairs(details) do
      detailsByName[feature.name] = feature
    end

    -- Summary line
    local summary = ctx.status.formatSummary()
    table.insert(menu, {
      title = summary,
      disabled = true
    })

    table.insert(menu, { title = "-" })

    -- Show details option
    table.insert(menu, {
      title = "Show Details...",
      fn = function()
        showDetailedStatus(ctx)
      end
    })

    table.insert(menu, { title = "-" })
    table.insert(menu, {
      title = "Checked items are enabled. Click to toggle and reload.",
      disabled = true
    })

    table.insert(menu, { title = "-" })

    -- Individual feature toggles
    for _, feature in ipairs(ctx.features and ctx.features.list or {}) do
      local item = buildFeatureToggleItem(ctx, feature, detailsByName)
      table.insert(menu, {
        title = item.title,
        checked = item.checked,
        disabled = item.disabled,
        fn = item.fn
      })
    end

    return menu
  end)

  return result.ok()
end

-- Update function called after all features are loaded
function M.update(ctx)
  updateMenubar(ctx)
end

return M
