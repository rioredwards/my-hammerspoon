-- Key capture functionality for hotkey configuration

local M = {}

local ctx = nil

local modifierSymbols = {
  cmd = "⌘",
  alt = "⌥",
  ctrl = "⌃",
  shift = "⇧",
  fn = "fn",
}

local keySymbols = {
  escape = "⎋",
  tab = "⇥",
  delete = "⌫",
  ["return"] = "↩",
  left = "←",
  right = "→",
  up = "↑",
  down = "↓",
}

-- Reverse mapping from modifierSymbols to modifier names
local modifierSymbolToName = {}
for modifierName, symbol in pairs(modifierSymbols) do
  modifierSymbolToName[symbol] = modifierName
end

-- Reverse mapping from keySymbols to key names
local keySymbolToName = {}
for keyName, symbol in pairs(keySymbols) do
  keySymbolToName[symbol] = keyName
end

local keyListener = nil
local isListening = false

-- Captures key and modifier information from an event
function G_captureKeys(event)
  local flags = hs.eventtap.checkKeyboardModifiers()
  ctx.log.all.log("Flags: " .. hs.inspect(flags))
  local keyCode = event:getKeyCode()
  local key = hs.keycodes.map[keyCode] or "?"
  local modifiers = {}

  -- Collect raw modifier names
  if flags.cmd then table.insert(modifiers, "cmd") end
  if flags.alt then table.insert(modifiers, "alt") end
  if flags.ctrl then table.insert(modifiers, "ctrl") end
  if flags.shift then table.insert(modifiers, "shift") end
  if flags.fn then table.insert(modifiers, "fn") end
  if flags.escape then table.insert(modifiers, "escape") end
  if flags.tab then table.insert(modifiers, "tab") end
  if flags.delete then table.insert(modifiers, "delete") end
  if flags["return"] then table.insert(modifiers, "return") end

  return {
    key = key,
    flags = flags,
    modifiers = modifiers
  }
end

-- Processes and remaps the captured key data
local function processAndRemapKeys(keyData)
  local key = keyData.key
  local modifiers = keyData.modifiers
  local output = ""

  -- Map raw modifier names to symbols
  for _, modifierName in ipairs(modifiers) do
    if modifierSymbols[modifierName] then
      output = output .. modifierSymbols[modifierName]
    end
  end

  -- Map key symbols to key names
  if keySymbols[key] then
    key = keySymbols[key]
  elseif #key == 1 then
    -- Capitalize single letters
    key = string.upper(key)
  end

  output = output .. key
  return output
end

-- Main function that orchestrates key capture and processing
function HK_startKeyCapture()
  if isListening then return end
  isListening = true

  -- User needs visual feedback that key capture mode is active
  ctx.log.all.log("🎧 Listening...", 3.0)

  keyListener = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    -- Capture keys
    local keyData = G_captureKeys(event)

    -- Process and remap
    local output = processAndRemapKeys(keyData)

    -- Output
    hs.pasteboard.setContents(output)
    hs.alert.closeAll()
    -- User needs visual confirmation of what was copied
    ctx.log.all.success("✅ Copied:  " .. output, 2.0)

    -- Clean up
    if keyListener then
      keyListener:stop()
      keyListener = nil
    end
    isListening = false
    return true
  end)

  if keyListener then
    keyListener:start()
  end
end

-- Parses a key combo string (like "⌘⌥⌃⇧T") and converts it to hotkeys table format
function G_parseKeyComboString(keyComboString)
  ctx.log.all.log("Parsing key combo string: " .. keyComboString)
  local mods = {}
  local remainingString = keyComboString

  -- Parse symbols from the beginning of the string
  local i = 0
  local foundModifier = true
  while foundModifier and #remainingString > 0 and i < 10 do
    i = i + 1
    foundModifier = false
    for symbol, modifierName in pairs(modifierSymbolToName) do
      if string.find(remainingString, symbol) then
        table.insert(mods, modifierName)
        remainingString = string.gsub(remainingString, symbol, "", 1)
        foundModifier = true
        break
      end
    end
  end

  -- What's left is the key
  local key = remainingString

  -- Map key symbols to key names
  if keySymbolToName[key] then
    key = keySymbolToName[key]
  elseif #key == 1 and key:match("%a") then
    key = string.upper(key)
  end

  ctx.log.all.log("Parsed key combo: " .. hs.inspect(mods) .. " " .. key)

  return {
    mods = mods,
    key = key
  }
end

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  -- Export functions to global scope
  _G.G_captureKeys = G_captureKeys
  _G.G_parseKeyComboString = G_parseKeyComboString

  ctx.log.console.success("KeyCapture feature initialized")

  return result.ok()
end

return M
