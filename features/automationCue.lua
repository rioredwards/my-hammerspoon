-- Fullscreen click-through overlay for automation "hands off" cues.

local M = {}

local SETTINGS_KEY = "automationCue.gradient"
local HANDLER_NAME = "automationCuePanel"

local overlay = nil
local panel = nil
local userContent = nil
local previewEnabled = false

local DEFAULTS = {
  centerX = 0,
  centerY = 0,
  edgeStart = 0.85,
  colors = {
    { red = 0.42, green = 0.48, blue = 0.54, alpha = 0.0 },
    { red = 0.48, green = 0.51, blue = 0.50, alpha = 0.05 },
    { red = 0.55, green = 0.50, blue = 0.42, alpha = 0.22 },
  },
}

local config = {}

local function cloneColor(color)
  return {
    red = color.red,
    green = color.green,
    blue = color.blue,
    alpha = color.alpha,
  }
end

local function loadConfig()
  local stored = hs.settings.get(SETTINGS_KEY)
  if type(stored) ~= "table" then
    config = {
      centerX = DEFAULTS.centerX,
      centerY = DEFAULTS.centerY,
      edgeStart = DEFAULTS.edgeStart,
      colors = {
        cloneColor(DEFAULTS.colors[1]),
        cloneColor(DEFAULTS.colors[2]),
        cloneColor(DEFAULTS.colors[3]),
      },
    }
    return
  end

  config.centerX = tonumber(stored.centerX) or DEFAULTS.centerX
  config.centerY = tonumber(stored.centerY) or DEFAULTS.centerY
  config.edgeStart = tonumber(stored.edgeStart) or DEFAULTS.edgeStart
  config.colors = {}

  for i = 1, 3 do
    local src = type(stored.colors) == "table" and stored.colors[i] or DEFAULTS.colors[i]
    config.colors[i] = {
      red = tonumber(src.red) or DEFAULTS.colors[i].red,
      green = tonumber(src.green) or DEFAULTS.colors[i].green,
      blue = tonumber(src.blue) or DEFAULTS.colors[i].blue,
      alpha = tonumber(src.alpha) or DEFAULTS.colors[i].alpha,
    }
  end
end

local function saveConfig()
  hs.settings.set(SETTINGS_KEY, {
    centerX = config.centerX,
    centerY = config.centerY,
    edgeStart = config.edgeStart,
    colors = {
      cloneColor(config.colors[1]),
      cloneColor(config.colors[2]),
      cloneColor(config.colors[3]),
    },
  })
end

local function destroyOverlay()
  if overlay then
    overlay:delete()
    overlay = nil
  end
end

local function synthesizeGradientColors()
  local edgeStart = config.edgeStart or DEFAULTS.edgeStart
  local stopCount = 9
  local colors = {}

  for i = 1, stopCount do
    local pos = (i - 1) / (stopCount - 1)
    if pos < edgeStart then
      table.insert(colors, cloneColor(config.colors[1]))
    elseif pos < edgeStart + (1 - edgeStart) * 0.55 then
      table.insert(colors, cloneColor(config.colors[2]))
    else
      table.insert(colors, cloneColor(config.colors[3]))
    end
  end

  return colors
end

local function gradientElements()
  return {
    {
      type = "rectangle",
      action = "fill",
      frame = { x = "0%", y = "0%", w = "100%", h = "100%" },
      fillGradient = "radial",
      fillGradientCenter = { x = config.centerX, y = config.centerY },
      fillGradientColors = synthesizeGradientColors(),
    },
  }
end

local function showOverlay()
  destroyOverlay()

  local frame = hs.screen.mainScreen():fullFrame()
  overlay = hs.canvas.new(frame)
  overlay:appendElements(gradientElements())
  overlay:level(hs.canvas.windowLevels.overlay)
  overlay:clickActivating(false)
  overlay:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
  overlay:show()
end

local function configToLuaSnippet()
  local c = config.colors
  return string.format([[
fillGradient = "radial",
fillGradientCenter = { x = 0.00, y = 0.00 },
edgeStart = 0.66,
fillGradientColors = {
  { red = 0.00, green = 0.00, blue = 0.25, alpha = 0.00 },
  { red = 0.00, green = 0.00, blue = 0.50, alpha = 0.18 },
  { red = 0.24, green = 0.66, blue = 0.95, alpha = 0.15 },
},
]], config.centerX, config.centerY, config.edgeStart or DEFAULTS.edgeStart,
    c[1].red, c[1].green, c[1].blue, c[1].alpha,
    c[2].red, c[2].green, c[2].blue, c[2].alpha,
    c[3].red, c[3].green, c[3].blue, c[3].alpha)
end

local function applyUpdate(data)
  if type(data.centerX) == "number" then config.centerX = data.centerX end
  if type(data.centerY) == "number" then config.centerY = data.centerY end
  if type(data.edgeStart) == "number" then config.edgeStart = data.edgeStart end

  if type(data.colors) == "table" then
    for i = 1, 3 do
      local src = data.colors[i]
      if type(src) == "table" then
        for channel in pairs(config.colors[i]) do
          if type(src[channel]) == "number" then
            config.colors[i][channel] = src[channel]
          end
        end
      end
    end
  end

  saveConfig()

  if previewEnabled then
    showOverlay()
  end
end

local function panelHTML()
  local c = config.colors
  return string.format([[
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Automation Cue</title>
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 16px;
      font: 13px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #1c1c1e;
      color: #f2f2f7;
    }
    h1 { font-size: 18px; margin: 0 0 4px; }
    p { margin: 0 0 16px; color: #98989d; }
    section {
      background: #2c2c2e;
      border-radius: 10px;
      padding: 12px;
      margin-bottom: 12px;
    }
    h2 {
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.04em;
      color: #8e8e93;
      margin: 0 0 10px;
    }
    .row {
      display: grid;
      grid-template-columns: 72px 1fr 44px;
      gap: 8px;
      align-items: center;
      margin-bottom: 8px;
    }
    .row label { color: #d1d1d6; }
    input[type="range"] { width: 100%%; }
    .val { text-align: right; color: #aeaeb2; font-variant-numeric: tabular-nums; }
    .swatch {
      height: 28px;
      border-radius: 6px;
      border: 1px solid #3a3a3c;
      margin-top: 4px;
    }
    .toolbar {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      margin-bottom: 12px;
    }
    button {
      background: #3a3a3c;
      color: #fff;
      border: none;
      border-radius: 8px;
      padding: 8px 12px;
      cursor: pointer;
    }
    button.primary { background: #0a84ff; }
    label.check {
      display: flex;
      align-items: center;
      gap: 8px;
      margin: 0;
      color: #f2f2f7;
    }
  </style>
</head>
<body>
  <h1>Automation Cue</h1>
  <p>Radial gradient overlay tuning</p>

  <div class="toolbar">
    <label class="check"><input type="checkbox" id="preview" %s> Live preview</label>
    <button type="button" id="showBtn">Show</button>
    <button type="button" id="hideBtn">Hide</button>
    <button type="button" id="resetBtn">Reset</button>
    <button type="button" id="copyBtn" class="primary">Copy Lua</button>
  </div>

  <section>
    <h2>Gradient shape</h2>
    <div class="row"><label>Edge start</label><input type="range" id="edgeStart" min="0.5" max="0.95" step="0.01" value="%.2f"><span class="val" id="edgeStartVal">%.2f</span></div>
    <p style="margin:0;font-size:12px;color:#8e8e93;">Higher pushes mid/edge color stops closer to the screen edge.</p>
  </section>

  <section>
    <h2>Gradient center</h2>
    <div class="row"><label>Center X</label><input type="range" id="centerX" min="-1" max="1" step="0.01" value="%.2f"><span class="val" id="centerXVal">%.2f</span></div>
    <div class="row"><label>Center Y</label><input type="range" id="centerY" min="-1" max="1" step="0.01" value="%.2f"><span class="val" id="centerYVal">%.2f</span></div>
  </section>

  <section>
    <h2>Center stop</h2>
    <div class="row"><label>Red</label><input type="range" data-stop="0" data-channel="red" min="0" max="1" step="0.01" value="%.2f"><span class="val" data-val="0-red">%.2f</span></div>
    <div class="row"><label>Green</label><input type="range" data-stop="0" data-channel="green" min="0" max="1" step="0.01" value="%.2f"><span class="val" data-val="0-green">%.2f</span></div>
    <div class="row"><label>Blue</label><input type="range" data-stop="0" data-channel="blue" min="0" max="1" step="0.01" value="%.2f"><span class="val" data-val="0-blue">%.2f</span></div>
    <div class="row"><label>Alpha</label><input type="range" data-stop="0" data-channel="alpha" min="0" max="1" step="0.01" value="%.2f"><span class="val" data-val="0-alpha">%.2f</span></div>
    <div class="swatch" id="swatch0"></div>
  </section>

  <section>
    <h2>Mid stop</h2>
    <div class="row"><label>Red</label><input type="range" data-stop="1" data-channel="red" min="0" max="1" step="0.01" value="%.2f"><span class="val" data-val="1-red">%.2f</span></div>
    <div class="row"><label>Green</label><input type="range" data-stop="1" data-channel="green" min="0" max="1" step="0.01" value="%.2f"><span class="val" data-val="1-green">%.2f</span></div>
    <div class="row"><label>Blue</label><input type="range" data-stop="1" data-channel="blue" min="0" max="1" step="0.01" value="%.2f"><span class="val" data-val="1-blue">%.2f</span></div>
    <div class="row"><label>Alpha</label><input type="range" data-stop="1" data-channel="alpha" min="0" max="1" step="0.01" value="%.2f"><span class="val" data-val="1-alpha">%.2f</span></div>
    <div class="swatch" id="swatch1"></div>
  </section>

  <section>
    <h2>Edge stop</h2>
    <div class="row"><label>Red</label><input type="range" data-stop="2" data-channel="red" min="0" max="1" step="0.01" value="%.2f"><span class="val" data-val="2-red">%.2f</span></div>
    <div class="row"><label>Green</label><input type="range" data-stop="2" data-channel="green" min="0" max="1" step="0.01" value="%.2f"><span class="val" data-val="2-green">%.2f</span></div>
    <div class="row"><label>Blue</label><input type="range" data-stop="2" data-channel="blue" min="0" max="1" step="0.01" value="%.2f"><span class="val" data-val="2-blue">%.2f</span></div>
    <div class="row"><label>Alpha</label><input type="range" data-stop="2" data-channel="alpha" min="0" max="1" step="0.01" value="%.2f"><span class="val" data-val="2-alpha">%.2f</span></div>
    <div class="swatch" id="swatch2"></div>
  </section>

  <script>
    const handler = "%s";
    let debounce = null;

    function send(payload) {
      webkit.messageHandlers[handler].postMessage(JSON.stringify(payload));
    }

    function readConfig() {
      const colors = [ [], [], [] ];
      document.querySelectorAll('input[data-stop]').forEach((input) => {
        const stop = Number(input.dataset.stop);
        colors[stop][input.dataset.channel] = Number(input.value);
      });
      return {
        centerX: Number(document.getElementById('centerX').value),
        centerY: Number(document.getElementById('centerY').value),
        edgeStart: Number(document.getElementById('edgeStart').value),
        colors: colors.map((channels) => ({
          red: channels.red ?? 0,
          green: channels.green ?? 0,
          blue: channels.blue ?? 0,
          alpha: channels.alpha ?? 0,
        })),
      };
    }

    function updateSwatches() {
      const cfg = readConfig();
      cfg.colors.forEach((color, index) => {
        const el = document.getElementById('swatch' + index);
        el.style.background = `rgba(${Math.round(color.red * 255)}, ${Math.round(color.green * 255)}, ${Math.round(color.blue * 255)}, ${color.alpha})`;
      });
    }

    function queueUpdate() {
      clearTimeout(debounce);
      debounce = setTimeout(() => {
        send({ action: 'update', config: readConfig() });
        updateSwatches();
      }, 60);
    }

    function bindRange(id, valId) {
      const input = document.getElementById(id);
      const val = document.getElementById(valId);
      input.addEventListener('input', () => {
        val.textContent = Number(input.value).toFixed(2);
        queueUpdate();
      });
    }

    bindRange('centerX', 'centerXVal');
    bindRange('centerY', 'centerYVal');
    bindRange('edgeStart', 'edgeStartVal');

    document.querySelectorAll('input[data-stop]').forEach((input) => {
      const val = document.querySelector(`[data-val="${input.dataset.stop}-${input.dataset.channel}"]`);
      input.addEventListener('input', () => {
        val.textContent = Number(input.value).toFixed(2);
        queueUpdate();
      });
    });

    document.getElementById('preview').addEventListener('change', (event) => {
      send({ action: 'preview', enabled: event.target.checked });
    });

    document.getElementById('showBtn').addEventListener('click', () => send({ action: 'show' }));
    document.getElementById('hideBtn').addEventListener('click', () => send({ action: 'hide' }));
    document.getElementById('resetBtn').addEventListener('click', () => send({ action: 'reset' }));
    document.getElementById('copyBtn').addEventListener('click', () => send({ action: 'copy' }));

    updateSwatches();
  </script>
</body>
</html>
]], previewEnabled and "checked" or "",
    config.edgeStart or DEFAULTS.edgeStart, config.edgeStart or DEFAULTS.edgeStart,
    config.centerX, config.centerX,
    config.centerY, config.centerY,
    c[1].red, c[1].red, c[1].green, c[1].green, c[1].blue, c[1].blue, c[1].alpha, c[1].alpha,
    c[2].red, c[2].red, c[2].green, c[2].green, c[2].blue, c[2].blue, c[2].alpha, c[2].alpha,
    c[3].red, c[3].red, c[3].green, c[3].green, c[3].blue, c[3].blue, c[3].alpha, c[3].alpha,
    HANDLER_NAME)
end

local function closePanel()
  if panel then
    panel:delete()
    panel = nil
  end
end

local function openPanel()
  if panel then
    panel:html(panelHTML())
    panel:show()
    panel:bringToFront(true)
    return true
  end

  userContent = hs.webview.usercontent.new(HANDLER_NAME)
  userContent:setCallback(function(message)
    local ok, data = pcall(hs.json.decode, message.body)
    if not ok or type(data) ~= "table" then
      return
    end

    if data.action == "update" and type(data.config) == "table" then
      applyUpdate(data.config)
    elseif data.action == "preview" then
      previewEnabled = data.enabled == true
      if previewEnabled then
        showOverlay()
      else
        destroyOverlay()
      end
    elseif data.action == "show" then
      showOverlay()
    elseif data.action == "hide" then
      destroyOverlay()
    elseif data.action == "reset" then
      config = {
        centerX = DEFAULTS.centerX,
        centerY = DEFAULTS.centerY,
        edgeStart = DEFAULTS.edgeStart,
        colors = {
          cloneColor(DEFAULTS.colors[1]),
          cloneColor(DEFAULTS.colors[2]),
          cloneColor(DEFAULTS.colors[3]),
        },
      }
      saveConfig()
      if panel then
        panel:html(panelHTML())
      end
      if previewEnabled then
        showOverlay()
      end
    elseif data.action == "copy" then
      hs.pasteboard.setContents(configToLuaSnippet())
      hs.alert.show("Copied gradient Lua to clipboard", 2)
    end
  end)

  local screen = hs.screen.mainScreen():frame()
  local width, height = 380, 820
  local rect = {
    x = screen.x + screen.w - width - 24,
    y = screen.y + 48,
    w = width,
    h = height,
  }

  panel = hs.webview.new(rect, {}, userContent)
    :windowTitle("Automation Cue")
    :windowStyle(hs.webview.windowMasks.titled | hs.webview.windowMasks.closable | hs.webview.windowMasks.resizable)
    :allowNewWindows(false)
    :allowTextEntry(true)
    :deleteOnClose(true)

  panel:windowCallback(function(action)
    if action == "closing" then
      panel = nil
      previewEnabled = false
      destroyOverlay()
    end
  end)

  panel:html(panelHTML())
  panel:show()
  panel:bringToFront(true)

  return true
end

function G_automationCueShow()
  showOverlay()
  return true
end

function G_automationCueHide()
  destroyOverlay()
  return true
end

function G_automationCueTune()
  openPanel()
  return true
end

function M.init()
  loadConfig()
  local result = require "core.utils.result"
  return result.ok()
end

return M


