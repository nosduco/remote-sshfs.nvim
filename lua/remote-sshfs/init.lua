local M = {}

local default_opts = {
  select_prompts = false,
  connections = {
    ssh_config_path = vim.fn.expand "$HOME" .. "/.ssh/config",
    custom_hosts = {},
  },
  mounts = {
    base_dir = vim.fn.expand "$HOME" .. "/.sshfs/",
    unmount_on_exit = true,
  },
  handlers = {
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
    },
  },
  log = {
    enable = false,
    truncate = false,
    types = {
      all = false,
      config = false,
      sshfs = false,
    },
  },
}

M.setup_commands = function() end

M.setup_auto_commands = function() end

M.validate_options = function(opts) end

M.setup = function(config)
  M.validate_options(config)

  local opts = config and vim.tbl_deep_extend("force", default_opts, config) or default_opts

  require("remote-sshfs.connections").setup(opts)
  require("remote-sshfs.utils").setup(opts)
  require("remote-sshfs.handler").setup(opts)

  M.setup_commands()
  M.setup_auto_commands()
end

return M
