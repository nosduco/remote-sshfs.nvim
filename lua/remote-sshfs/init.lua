local M = {}

local default_opts = {
  connections = {
    ssh_configs = {
      vim.fn.expand "$HOME" .. "/.ssh/config",
      "/etc/ssh/ssh_config",
      -- "/path/to/custom/ssh_config"
    },
    sshfs_args = {
      "-o reconnect",
      "-o ConnectTimeout=5",
    },
  },
  mounts = {
    base_dir = vim.fn.expand "$HOME" .. "/.sshfs/",
    unmount_on_exit = true,
  },
  handlers = {
    on_connect = {
      change_dir = true,
    },
    on_disconnect = {
      clean_mount_folders = false,
    },
    on_add = {},
    on_edit = {},
  },
  ui = {
    select_prompts = false, -- not yet implemented
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
      util = false,
      handler = false,
      sshfs = false,
    },
  },
}

M.setup_commands = function()
  -- Create commands to connect/edit/reload/disconnect/find_files/live_grep
  vim.api.nvim_create_user_command("RemoteSSHFSConnect", function()
    require("telescope").extensions["remote-sshfs"].connect()
  end, {})
  vim.api.nvim_create_user_command("RemoteSSHFSEdit", function()
    require("telescope").extensions["remote-sshfs"].edit()
  end, {})
  vim.api.nvim_create_user_command("RemoteSSHFSReload", function()
    require("remote-sshfs.connections").reload()
  end, {})
  vim.api.nvim_create_user_command("RemoteSSHFSDisconnect", function()
    require("remote-sshfs.connections").unmount_host()
  end, {})
  vim.api.nvim_create_user_command("RemoteSSHFSFindFiles", function()
    require("telescope").extensions["remote-sshfs"].find_files {}
  end, {})
  vim.api.nvim_create_user_command("RemoteSSHFSLiveGrep", function()
    require("telescope").extensions["remote-sshfs"].live_grep {}
  end, {})
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
