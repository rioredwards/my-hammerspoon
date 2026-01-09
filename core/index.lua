-- Index file for core module

local core = {}

function core.init()
  local utils = require "core.utils.coreUtils"
  local log = require "core.log"
  local result = require "core.utils.result"
  local context = require "core.context"
  local status = require "core.status"

  return {
    utils = utils,
    log = log,
    result = result,
    context = context,
    status = status
  }
end

return core
