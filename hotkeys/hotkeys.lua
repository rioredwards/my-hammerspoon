-- Hotkey binding system
-- Loads hotkeys from JSON and binds them

local M = {}

local ctx = nil

-- Converts any keyCombo strings in the Hotkeys table to mods/key format
local function processHotkeysTable(hotkeysTable)
  local newHotkeysTable = {}
  for _, hotkey in ipairs(hotkeysTable) do
    if hotkey.keyCombo and not hotkey.mods then
      -- Convert keyCombo string to mods/key format
      local parsed = _G.G_parseKeyComboString(hotkey.keyCombo)
      local newHotkey = {
        action = hotkey.action,
        mods = parsed.mods,
        key = parsed.key,
      }
      table.insert(newHotkeysTable, newHotkey)
    elseif hotkey.mods and hotkey.key then
      -- Already in mods/key format, use as-is
      table.insert(newHotkeysTable, {
        action = hotkey.action,
        mods = hotkey.mods,
        key = hotkey.key,
      })
    end
  end
  return newHotkeysTable
end

function G_bindAllHotkeys(hotkeysTable)
  if not ctx then
    return
  end

  local processedHotkeys = processHotkeysTable(hotkeysTable)

  -- Bind hotkeys to actions
  for _, hotkey in ipairs(processedHotkeys) do
    if hotkey.action then
      hs.hotkey.bind(hotkey.mods, hotkey.key, hotkey.action)
    else
      ctx.log.all.warn("Skipping hotkey with no action: " .. hs.inspect(hotkey))
    end
  end
end

function M.init(context)
  local result = require "core.utils.result"

  ctx = context

  -- Load hotkeys from JSON (must be called after hotkeyJsonLoader is initialized)
  if not _G.G_loadHotkeysFromJson then
    return result.fail("DEPENDENCY_MISSING", "G_loadHotkeysFromJson not available (hotkeyJsonLoader must load first)",
      { level = "error" })
  end

  local hotkeys = _G.G_loadHotkeysFromJson()

  -- Export function to global scope
  _G.G_bindAllHotkeys = G_bindAllHotkeys

  -- Bind all hotkeys
  G_bindAllHotkeys(hotkeys)

  ctx.log.console.success("Hotkeys feature initialized and bound")

  return result.ok()
end

return M
