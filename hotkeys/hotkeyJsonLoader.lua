-- JSON Hotkey Loader Module
-- Loads hotkey definitions from hotkeys.json and transforms them to the format expected by bindAllHotkeys

local M = {}

local ctx = nil

-- Convert modifierKeys string (like "⌘⌥⌃") to mods array (like {"cmd", "alt", "ctrl"})
function M.convertModifierKeysToMods(modifierKeysString)
  local modifierSymbolToName = {
    ["⌘"] = "cmd",
    ["⌥"] = "alt",
    ["⌃"] = "ctrl",
    ["⇧"] = "shift",
    ["fn"] = "fn"
  }

  local mods = {}
  local remainingString = modifierKeysString or ""

  -- Scan through the string in order, finding symbols as we go
  local pos = 1
  while pos <= #remainingString do
    local found = false
    for symbol, modifierName in pairs(modifierSymbolToName) do
      if remainingString:sub(pos, pos + #symbol - 1) == symbol then
        table.insert(mods, modifierName)
        pos = pos + #symbol
        found = true
        break
      end
    end

    if not found then
      pos = pos + 1
    end
  end

  return mods
end

-- Convert key symbol (like "⌫", "←") to key name (like "delete", "left")
function M.convertKeySymbolToName(keyString)
  local keySymbolToName = {
    ["⎋"] = "escape",
    ["⇥"] = "tab",
    ["⌫"] = "delete",
    ["↩"] = "return",
    ["←"] = "left",
    ["→"] = "right",
    ["↑"] = "up",
    ["↓"] = "down"
  }

  if keySymbolToName[keyString] then
    return keySymbolToName[keyString]
  end

  assert(type(keyString) == "string", "Key string is not a string: " .. tostring(keyString))

  if #keyString == 1 and keyString:match("%a") then
    return string.upper(keyString)
  end

  return keyString
end

-- -- Loading hotkeys from: ~/.hammerspoon/config/hotkeys.hammerspoon.jsonc

-- Strip JSONC single-line comments (// ...) from JSON text
-- Preserves // inside strings and handles escaped characters properly
function M.stripJsoncComments(jsonText)
  local result = {}
  local inString = false
  local escapeNext = false
  local i = 1

  while i <= #jsonText do
    local char = jsonText:sub(i, i)
    local nextChar = i < #jsonText and jsonText:sub(i + 1, i + 1) or ""

    if escapeNext then
      -- Previous character was backslash, this is escaped
      table.insert(result, char)
      escapeNext = false
      i = i + 1
    elseif char == "\\" then
      -- Escape character - next character is escaped
      table.insert(result, char)
      escapeNext = true
      i = i + 1
    elseif char == '"' then
      -- Toggle string state
      table.insert(result, char)
      inString = not inString
      i = i + 1
    elseif not inString and char == "/" and nextChar == "/" then
      -- Single-line comment - skip to end of line
      while i <= #jsonText and jsonText:sub(i, i) ~= "\n" do
        i = i + 1
      end
      -- Include the newline if present
      if i <= #jsonText then
        table.insert(result, "\n")
        i = i + 1
      end
    else
      -- Regular character
      table.insert(result, char)
      i = i + 1
    end
  end

  return table.concat(result)
end

function G_loadHotkeysFromJson()
  if not ctx then
    return {}
  end

  local hotkeyJsonPath = ctx.constants.HOTKEY_JSON_PATH

  -- Expand ~ to home directory (io.open doesn't expand ~)
  if hotkeyJsonPath:sub(1, 1) == "~" then
    local homeDir = os.getenv("HOME")
    if homeDir then
      hotkeyJsonPath = homeDir .. hotkeyJsonPath:sub(2)
    end
  end

  -- Read file as text to support JSONC comments
  local file = io.open(hotkeyJsonPath, "r")
  if not file then
    ctx.log.all.error("Error: Failed to open hotkeys.hammerspoon.jsonc")
    return {}
  end

  local jsonText = file:read("*all")
  file:close()

  -- Strip JSONC comments
  local cleanedJsonText = M.stripJsoncComments(jsonText)

  -- Parse JSON
  local jsonData = hs.json.decode(cleanedJsonText)

  if not jsonData then
    ctx.log.all.error("Error: Failed to parse hotkeys.hammerspoon.jsonc")
    return {}
  end

  if not jsonData.hotkeys then
    ctx.log.all.error("Error: hotkeys.hammerspoon.jsonc missing 'hotkeys' array")
    return {}
  end

  -- Transform JSON entries to format expected by bindAllHotkeys
  local hotkeysTable = {}

  for _, hotkeyEntry in ipairs(jsonData.hotkeys) do
    local modifierKeys = hotkeyEntry[1]
    local keySymbol    = hotkeyEntry[2]
    local actionName   = hotkeyEntry[3]

    -- Resolve function reference from global scope with HK_ prefix
    local action       = nil
    if actionName and actionName ~= "" then
      local prefixedActionName = "HK_" .. actionName
      action = _G[prefixedActionName]
      if not action then
        ctx.log.all.error("Error: Function '" .. prefixedActionName .. "' not found")
      end
    end

    -- Convert modifierKeys string to mods array
    local mods = M.convertModifierKeysToMods(modifierKeys)

    -- Convert key symbol to key name if needed
    local key = M.convertKeySymbolToName(keySymbol)

    table.insert(hotkeysTable, {
      action = action,
      mods   = mods,
      key    = key,
    })
  end

  return hotkeysTable
end

-- Load app layers from JSON (reuses the same JSON loading logic)
function G_loadAppLayersFromJson()
  if not ctx then
    return {}
  end

  local hotkeyJsonPath = ctx.constants.HOTKEY_JSON_PATH

  -- Expand ~ to home directory
  if hotkeyJsonPath:sub(1, 1) == "~" then
    local homeDir = os.getenv("HOME")
    if homeDir then
      hotkeyJsonPath = homeDir .. hotkeyJsonPath:sub(2)
    end
  end

  -- Read file as text to support JSONC comments
  local file = io.open(hotkeyJsonPath, "r")
  if not file then
    ctx.log.all.error("Error: Failed to open hotkeys.hammerspoon.jsonc for app layers")
    return {}
  end

  local jsonText = file:read("*all")
  file:close()

  -- Strip JSONC comments
  local cleanedJsonText = M.stripJsoncComments(jsonText)

  -- Parse JSON
  local jsonData = hs.json.decode(cleanedJsonText)

  if not jsonData then
    ctx.log.all.error("Error: Failed to parse hotkeys.hammerspoon.jsonc for app layers")
    return {}
  end

  -- Extract appLayers section
  if jsonData.appLayers and type(jsonData.appLayers) == "table" then
    return jsonData.appLayers
  end

  return {}
end

-- Transform app layer hotkey entries to the same format as regular hotkeys
-- Takes the same [modifierKeys, keySymbol, actionName] format and converts it
function M.transformAppLayerHotkeys(hotkeyEntries)
  local hotkeysTable = {}

  for _, hotkeyEntry in ipairs(hotkeyEntries) do
    local modifierKeys = hotkeyEntry[1]
    local keySymbol = hotkeyEntry[2]
    local actionName = hotkeyEntry[3]

    -- Resolve function reference from global scope with HK_ prefix
    local action = nil
    if actionName and actionName ~= "" then
      local prefixedActionName = "HK_" .. actionName
      action = _G[prefixedActionName]
      if not action then
        ctx.log.console.warn(string.format("Function '%s' not found", prefixedActionName))
      end
    end

    -- Convert modifierKeys string to mods array
    local mods = M.convertModifierKeysToMods(modifierKeys)

    -- Convert key symbol to key name if needed
    local key = M.convertKeySymbolToName(keySymbol)

    table.insert(hotkeysTable, {
      action = action,
      mods = mods,
      key = key,
    })
  end

  return hotkeysTable
end

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  -- Export functions to global scope
  _G.G_loadHotkeysFromJson = G_loadHotkeysFromJson
  _G.G_loadAppLayersFromJson = G_loadAppLayersFromJson

  ctx.log.console.success("HotkeyJsonLoader feature initialized")

  return result.ok()
end

return M
