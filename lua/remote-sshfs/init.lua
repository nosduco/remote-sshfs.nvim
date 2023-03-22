local connections = require "remote-sshfs.connections"

local M = {}

local defaults = {
  connections = {
    ssh_config_path = vim.fn.expand "$HOME" .. "/.ssh/config",
    custom_hosts = {},
  },
  mounts = {
    base_dir = vim.fn.expand "$HOME" .. "/.sshfs/",
    unmount_on_exit = true,
  },
  actions = {
    on_connect = {
      change_dir = true,
      find_files = false,
    },
    on_disconnect = {
      clean_mount_folders = false,
    },
    on_add = {},
    on_edit = {},
  },
  ui = {
    confirm = {
      connect = false,
      change_dir = false,
    }
  },
  log = {
    enable = false,
    truncate = false,
    types = {
      all = false,
      config = false,
      sshfs = false,
    }
  }
}

M.setup = function(config)
  config = config and vim.tbl_deep_extend("force", defaults, config) or defaults

  connections.init(config)
end

return M
