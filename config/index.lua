-- Index file for config module

local config = {}

function config.init()
  local constants = require "config.constants"
  return {
    constants = constants
  }
end

return config
