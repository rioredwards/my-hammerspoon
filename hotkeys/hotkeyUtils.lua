-- Converts any keyCombo strings in the Hotkeys table to mods/key format
-- Also includes entries that already have mods/key format
local function processHotkeysTable(hotkeysTable)
  local newHotkeysTable = {}
  for _, hotkey in ipairs(hotkeysTable) do
    if hotkey.keyCombo and not hotkey.mods then
      -- Convert keyCombo string to mods/key format
      local parsed = G_parseKeyComboString(hotkey.keyCombo)
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
  local processedHotkeys = processHotkeysTable(hotkeysTable)
  -- print("Binding hotkeys: " .. hs.inspect(processedHotkeys))

  -- Bind hotkeys to actions
  for _, hotkey in ipairs(processedHotkeys) do
    -- print("Binding hotkey: " .. hs.inspect(hotkey))
    hs.hotkey.bind(hotkey.mods, hotkey.key, hotkey.action)
  end
end
