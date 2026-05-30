-- Clipboard formatter with picker UI

local M = {}
local ctx = nil

local formatters = {
  { text = "Trim Whitespace", subText = "strip per-line whitespace, collapse blank lines", cmd = "python3 -c \"import sys, re; text = '\\n'.join(line.strip() for line in sys.stdin.read().splitlines()); sys.stdout.write(re.sub(r'\\n{2,}', '\\n', text))\"" },
  { text = "JSON Pretty",      subText = "jq .",                       cmd = "jq ." },
  { text = "JSON Minify",      subText = "jq -c .",                    cmd = "jq -c ." },
  { text = "Prettier JS/TS",   subText = "prettier --parser babel",    cmd = "prettier --stdin-filepath file.js" },
  { text = "Prettier CSS",     subText = "prettier --parser css",      cmd = "prettier --stdin-filepath file.css" },
  { text = "Prettier HTML",    subText = "prettier --parser html",     cmd = "prettier --stdin-filepath file.html" },
  { text = "Prettier Shell",   subText = "shfmt -i 2",                cmd = "shfmt -i 2 -" },
  { text = "Sort Lines",    subText = "sort lines alphabetically",      cmd = "sort" },
  { text = "Unique Lines",  subText = "deduplicate + sort lines",       cmd = "sort -u" },
  { text = "URL Decode",    subText = "urllib.parse.unquote",           cmd = "python3 -c \"import sys, urllib.parse; sys.stdout.write(urllib.parse.unquote(sys.stdin.read().strip()))\"" },
}

local function applyFormatter(cmd)
  local content = hs.pasteboard.getContents()
  if not content or content == "" then
    if ctx then ctx.log.alert.warn("Clipboard empty") end
    return
  end

  local tmpFile = os.tmpname()
  local f = io.open(tmpFile, "w")
  if not f then
    if ctx then ctx.log.alert.error("Could not create temp file") end
    return
  end
  f:write(content)
  f:close()

  local result, ok = hs.execute(cmd .. " < '" .. tmpFile .. "' 2>&1", true)
  os.remove(tmpFile)

  if ok and result and result ~= "" then
    hs.pasteboard.setContents(result)
    if ctx then ctx.log.alert.success("Clipboard formatted") end
  else
    local msg = (result and result ~= "") and ("Format failed: " .. result:gsub("\n", " ")) or "Format failed"
    if ctx then ctx.log.alert.error(msg) end
  end
end

function HK_formatClipboard()
  local chooser = hs.chooser.new(function(choice)
    if not choice then return end
    applyFormatter(choice.cmd)
  end)
  chooser:choices(formatters)
  chooser:show()
end

function M.init(context)
  local result = require "core.utils.result"
  ctx = context
  context.log.console.success("Clipboard formatter initialized")
  return result.ok()
end

return M
