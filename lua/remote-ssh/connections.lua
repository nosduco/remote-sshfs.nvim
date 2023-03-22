local utils = require "remote-ssh.utils"
local hosts = {}

local M = {}

M.init = function(config)
  -- M.init = function(connections_config)
  hosts = utils.parse_hosts_from_config(config)
  -- print(vim.inspect(hosts))
end

M.list_hosts = function()
  return hosts
end

return M
