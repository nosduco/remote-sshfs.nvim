local fn = vim.fn
local connections = require("remote-sshfs.connections")

local M = {}

local defaults = {
  mnt_base_dir = vim.fn.expand "$HOME" .. "/mnt",
  ssh_config_path = vim.fn.expand "$HOME" .. "/.ssh/config",
}

M.setup = function(config)
  config = config and vim.tbl_deep_extend("force", defaults, config) or defaults

  connections.init(config)
end

-- M.list_hosts = function()
--   connections.hosts
-- end

return M
