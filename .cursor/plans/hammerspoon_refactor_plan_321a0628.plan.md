---
name: Hammerspoon Refactor Plan
overview: Refactor Hammerspoon configuration to use proper modularization with graceful error handling, result patterns, and a plugin-based architecture where features can fail without crashing the entire app.
todos:
  - id: create-result-helper
    content: Create core/utils/result.lua with ok() and fail() helper functions
    status: completed
  - id: create-context
    content: Create core/context.lua to build and return context object with log, env, constants, utils
    status: completed
  - id: create-status-tracker
    content: Create core/status.lua to track feature initialization results and provide status summary
    status: completed
  - id: update-core-index
    content: Update core/index.lua to export result, context, and status modules
    status: completed
  - id: refactor-bootstrapper
    content: Refactor init.lua to load core modules, create context, load features as plugins, track results, and show status
    status: completed
  - id: create-status-dashboard
    content: Create features/statusDashboard.lua with menubar item showing feature status
    status: completed
  - id: refactor-webview
    content: Refactor features/webview.lua to use init(ctx) pattern, implement graceful degradation with offline UI
    status: completed
  - id: refactor-ensure-local-server
    content: Refactor features/ensureLocalServer.lua to use init(ctx) pattern
    status: completed
  - id: refactor-lock-screen
    content: Refactor features/lockScreen.lua to use init(ctx) pattern
    status: completed
  - id: refactor-windows
    content: Refactor features/windows.lua to use init(ctx) pattern
    status: completed
  - id: refactor-remaining-features
    content: Refactor remaining features (keyCapture, openYoutubeLinks, reloadConfiguration, screenshot, showCalendar) to use init(ctx) pattern
    status: completed
  - id: refactor-hotkeys
    content: Refactor hotkeys/hotkeys.lua and hotkeys/hotkeyJsonLoader.lua to use init(ctx) pattern
    status: completed
  - id: remove-globals
    content: Remove all G_* global variable patterns and replace with context object usage
    status: completed
  - id: remove-safe-require
    content: Remove utils.safeRequire calls and replace with bootstrapper error handling
    status: completed
---

# Hammerspoon Refactoring Plan

## Overview

Refactor the codebase to implement a plugin-based architecture with structured error handling, result patterns, and graceful degradation. Features will be isolated so failures don't crash the entire app.

## Architecture Changes

### 1. Core Infrastructure

#### 1.1 Result Pattern Helper (`core/utils/result.lua`)

Create a new utility module for structured results:

```lua
local function ok(meta) return { ok = true, meta = meta or {} } end
local function fail(code, msg, meta) 
  return { 
    ok = false, 
    code = code, 
    msg = msg, 
    level = meta and meta.level or "error",
    meta = meta or {} 
  } 
end
```



#### 1.2 Context Object (`core/context.lua`)

Create a context object passed to all features containing:

- `log` - logging module
- `env` - environment variables
- `constants` - configuration constants
- `utils` - utility functions
- `notify` - notification function

#### 1.3 Status Tracker (`core/status.lua`)

Track feature initialization status:

- Store results for each feature
- Provide status summary
- Support menubar display

### 2. Feature Module Pattern

All features in `features/` will follow this pattern:

```lua


local M = {}

function M.init(ctx)
  -- Initialize feature
  -- Return result table
  return ok() or fail("CODE", "message", {level = "warn"})
end

function M.health(ctx)  -- optional
  -- Check runtime dependencies
  return ok() or fail("DEPENDENCY_MISSING", "message")
end

return M
```



### 3. Bootstrapper (`init.lua`)

Refactor `init.lua` to:

1. Load core modules first (hard-fail if these fail)
2. Create context object
3. Load features as plugins with error handling
4. Track initialization results
5. Display status dashboard in menubar
6. Show startup notification with summary

### 4. Specific Feature Refactors

#### 4.1 Webview Feature (`features/webview.lua`)

- Implement graceful degradation: show offline UI when server unavailable
- Create local HTML error page with retry functionality
- Don't fail init if server is down - initialize webview object anyway
- On open: attempt to load URL, fallback to offline UI if fails

#### 4.2 Other Features

Convert all features to use:

- `init(ctx)` function returning result
- Context object instead of globals
- Proper error handling

### 5. Migration Strategy

#### Phase 1: Core Infrastructure

- Create `core/utils/result.lua`
- Create `core/context.lua`
- Create `core/status.lua`
- Update `core/index.lua` to export these

#### Phase 2: Update Bootstrapper

- Refactor `init.lua` to use new patterns
- Implement feature loading loop
- Add status tracking

#### Phase 3: Migrate Features

Migrate features one by one:

1. `features/webview.lua` (highest priority - needs degradation)
2. `features/ensureLocalServer.lua`
3. `features/lockScreen.lua`
4. `features/windows.lua`
5. Remaining features

#### Phase 4: Cleanup

- Remove old `G_*` global patterns
- Remove `utils.safeRequire` calls (replace with bootstrapper logic)
- Update all references to use context object

### 6. Menubar Status Dashboard

Create `features/statusDashboard.lua`:

- Display feature status (✅ loaded, ⚠️ warnings, ❌ disabled)
- Click to show detailed status
- Auto-update when features change state

## File Changes

### New Files

- `core/utils/result.lua` - Result pattern helpers
- `core/context.lua` - Context object creation
- `core/status.lua` - Status tracking
- `features/statusDashboard.lua` - Menubar status display

### Modified Files

- `init.lua` - Complete rewrite as bootstrapper
- `core/index.lua` - Export new utilities
- `features/webview.lua` - Add init(), graceful degradation
- `features/ensureLocalServer.lua` - Convert to init() pattern
- `features/lockScreen.lua` - Convert to init() pattern
- `features/windows.lua` - Convert to init() pattern
- All other feature files - Convert to init() pattern
- `hotkeys/hotkeys.lua` - Convert to init() pattern

### Removed Patterns

- `G_*` global variables (replace with context)
- `utils.safeRequire` (replace with bootstrapper)
- Direct global access to `G_env`, `G_console`, `G_logger`

## Implementation Details

### Result Codes

Standardize on error codes:

- `DEPENDENCY_MISSING` - External dependency unavailable
- `CONFIG_ERROR` - Configuration issue
- `PERMISSION_DENIED` - Missing permissions
- `INIT_FAILED` - General initialization failure

### Severity Levels

- `error` - Feature disabled, user should fix
- `warn` - Feature works but with limitations

### Hard-Fail Conditions

Only hard-fail (crash) for:

- Core module syntax errors
- Required utilities missing (log, context)
- Fundamental config corruption

## Testing Strategy

1. Test each feature in isolation
2. Test with missing dependencies
3. Test with server offline (webview)