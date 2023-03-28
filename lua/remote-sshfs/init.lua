local M = {}

local default_opts = {
  connections = {
    ssh_configs = {
      vim.fn.expand "$HOME" .. "/.ssh/config",
      "/etc/ssh/ssh_config",
      -- "/path/to/custom/ssh_config"
    },
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
    select_prompts = false,
    confirm = {
      connect = true,
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

M.setup_commands = function()
  vim.api.nvim_create_user_command("RemoteSSHFSConnect", "Telescope remote-sshfs connect", {})
  vim.api.nvim_create_user_command("RemoteSSHFSEdit", "Telescope remote-sshfs edit", {})
  vim.api.nvim_create_user_command("RemoteSSHFSReload", function()
    require("remote-sshfs.connections").reload()
  end, {})
  vim.api.nvim_create_user_command("RemoteSSHFSDisconnect", function() end, {
    require("remote-sshfs.connections").unmount_host(),
  })
end

M.setup = function(config)
  local opts = config and vim.tbl_deep_extend("force", default_opts, config) or default_opts

  require("remote-sshfs.connections").setup(opts)
  require("remote-sshfs.ui").setup(opts)
  require("remote-sshfs.handler").setup(opts)
  require("remote-sshfs.log").setup(opts)

  M.setup_commands()
end

return M
