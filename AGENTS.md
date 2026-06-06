# AGENTS.md

Agent front door for this Hammerspoon config. Human front door: [README.md](README.md). General Hammerspoon/Lua/Spoon/`hs` CLI guidance lives in the `hammerspoon` skill (`.agents/skills/hammerspoon/SKILL.md`) — this file owns only repo-specific architecture and conventions.

This repo is symlinked into `~/.hammerspoon` via GNU stow from `~/.dotfiles`. Edit files here, not the symlinks.

## Architecture

`init.lua` is the bootstrapper. Load order (phases):

1. Core modules (`core.index`) — hard-fail if these break.
2. Config (`config.index`) — constants, etc.
3. Build the `ctx` context object (`core/context.lua`).
4. Feature registry: the `features` array in `init.lua`.
5. Load loop: each feature is `require`d and `init(ctx)`'d in order; failures are recorded, not fatal.

### Feature plugin model

Each `features/*.lua` (and the hotkey modules) returns a table `M` with:

```lua
local M = {}
function M.init(ctx)
  -- ... setup ...
  return require("core.utils.result").ok()   -- or .fail(code, msg, meta)
end
return M
```

- Return `result.ok(meta)` or `result.fail(code, msg, meta)` from `core/utils/result.lua`. `fail` carries `level` (`"error"` default, or `"warn"`). The status tracker records the result; it shows in the menubar menu.
- No `init`, or no return value, is treated as a legacy success.
- `ctx` provides: `ctx.log` (`.console` / `.alert` / `.all`, each with `.log/.warn/.error/.success`), `ctx.constants`, `ctx.utils`, `ctx.status`, `ctx.notify(msg, level, dur)`, `ctx.features` (`isEnabled`/`setEnabled`/`toggle`/`isLocked`/`list`).

### Hotkeys

Hotkeys are **not** wired in Lua per feature. A feature exposes a **global** function named `HK_<action>` (e.g. `function HK_launchSlack()`). Bindings live in `config/hotkeys.hammerspoon.jsonc`, keyed by `<action>`; the loader resolves them by prefixing `HK_` and looking up global scope. So a hotkey action must be a global `HK_` function, not a module export.

Every bound action is also auto-registered as a deep link, so `hammerspoon://<action>` triggers the same handler. For deeplink-only actions (no key binding), add the action name to a `deeplinks` array in `config/hotkeys.hammerspoon.jsonc`.

### Feature toggles

The status menubar menu shows each feature as a checkbox. Toggling writes the disabled-feature list to `hs.settings` (key `hammerspoon.disabledFeatures`) and reloads. Features marked `locked = true` in the registry can't be disabled and are force-enabled on every load.

## Adding a feature

1. Create `features/<name>.lua` returning `M` with `M.init(ctx)` → `result.ok()`.
2. Register it in the `features` array in `init.lua`. **Order matters**, and the hotkey modules (`hotkeyJsonLoader`, `hotkeys`) must stay **last** — they depend on `HK_` globals defined by earlier features.
3. If it needs a hotkey, define a global `HK_<action>` and add the binding in `config/hotkeys.hammerspoon.jsonc`.

## Footguns

- Register new features **before** the hotkey modules in `init.lua`, or their `HK_` functions won't bind.
- `HK_` functions are global by design; don't localize them.
- Core/config load is hard-fail; a syntax error there breaks the whole config. Feature load is soft-fail (recorded in the status menu).
