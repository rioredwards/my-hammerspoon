-- Clipboard formatter with picker UI

local M          = {}
local ctx        = nil

local IN_FILE    = "/tmp/hs_fmt_input.txt"
local ERR_FILE   = "/tmp/hs_fmt_err.txt"
local PY_FILE    = "/tmp/hs_fmt_script.py"

local formatters = {
  {
    text    = "Trim Whitespace",
    subText = "strip per-line whitespace, collapse blank lines",
    python  = [[
import sys, re
text = '\n'.join(line.strip() for line in sys.stdin.read().splitlines())
sys.stdout.write(re.sub(r'\n{2,}', '\n', text))
]],
  },
  {
    text    = "Strip Quote Markers",
    subText = "remove ▎ prefix from quoted text",
    python  = [[
import sys, re
p = re.compile(r'^\s*' + chr(0x258e) + r'\s?')
sys.stdout.write('\n'.join(p.sub('', line) for line in sys.stdin.read().splitlines()))
]],
  },
  { text = "JSON Pretty",    subText = "jq .",                      shell = "jq ." },
  { text = "JSON Minify",    subText = "jq -c .",                   shell = "jq -c ." },
  { text = "Prettier JS/TS", subText = "prettier --parser babel",   shell = "prettier --stdin-filepath file.js" },
  { text = "Prettier CSS",   subText = "prettier --parser css",     shell = "prettier --stdin-filepath file.css" },
  { text = "Prettier HTML",  subText = "prettier --parser html",    shell = "prettier --stdin-filepath file.html" },
  { text = "Prettier Shell", subText = "shfmt -i 2",                shell = "shfmt -i 2 -" },
  { text = "Sort Lines",     subText = "sort lines alphabetically", shell = "sort" },
  { text = "Unique Lines",   subText = "deduplicate + sort lines",  shell = "sort -u" },
  {
    text    = "URL Decode",
    subText = "urllib.parse.unquote",
    python  = [[
import sys, urllib.parse
sys.stdout.write(urllib.parse.unquote(sys.stdin.read().strip()))
]],
  },
}

local function writeFile(path, content)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(content)
  f:close()
  return true
end

local function readFile(path)
  local f = io.open(path, "r")
  if not f then return "" end
  local s = f:read("*all") or ""
  f:close()
  return s
end

local function runFormatter(formatter)
  local content = hs.pasteboard.getContents()
  if not content or content == "" then
    if ctx then ctx.log.alert.warn("Clipboard empty") end
    return
  end

  if not writeFile(IN_FILE, content) then
    if ctx then ctx.log.alert.error("Could not write temp file") end
    return
  end

  local shellCmd
  if formatter.python then
    if not writeFile(PY_FILE, formatter.python) then
      if ctx then ctx.log.alert.error("Could not write script file") end
      return
    end
    shellCmd = "python3 " .. PY_FILE .. " < " .. IN_FILE .. " 2>" .. ERR_FILE
  else
    shellCmd = formatter.shell .. " < " .. IN_FILE .. " 2>" .. ERR_FILE
  end

  local result, ok = hs.execute(shellCmd, true)
  local errMsg = readFile(ERR_FILE)

  if ok and result and result ~= "" then
    hs.pasteboard.setContents(result)
    if ctx then ctx.log.alert.success("Clipboard formatted") end
  else
    local detail = errMsg ~= "" and errMsg or (result or "no output")
    local msg = "Format failed: " .. detail:gsub("\n", " "):sub(1, 120)
    if ctx then
      ctx.log.console.error(msg)
      ctx.log.alert.error(msg)
    end
  end
end

function HK_formatClipboard()
  local chooser = hs.chooser.new(function(choice)
    if not choice then return end
    runFormatter(choice)
  end)
  chooser:choices(formatters)
  chooser:bgDark(true)
  chooser:fgColor({ red = 1, green = 1, blue = 1, alpha = 1 })
  chooser:subTextColor({ red = 0.55, green = 0.55, blue = 0.6, alpha = 1 })
  chooser:width(35)
  chooser:rows(8)
  chooser:searchSubText(true)
  chooser:placeholderText("Format clipboard...")
  chooser:show()
end

function M.init(context)
  local result = require "core.utils.result"
  ctx = context
  context.log.console.success("Clipboard formatter initialized")
  return result.ok()
end

return M
