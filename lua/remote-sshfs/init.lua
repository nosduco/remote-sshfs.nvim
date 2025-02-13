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
  picker = "fzf"
}

M.setup_commands = function(config)
  local picker
  if config.picker == "fzf" then
      picker = require("../fzf/remote-sshfs")
  else
      picker = require("telescope").extensions["remote-sshfs"]
  end

  -- Create commands to connect/edit/reload/disconnect/find_files/live_grep
  vim.api.nvim_create_user_command("RemoteSSHFSConnect", function(opts)
    if opts.args and opts.args ~= "" then
      local host = require("remote-sshfs.utils").parse_host_from_command(opts.args)
      require("remote-sshfs.connections").connect(host)
    else
      picker.connect()
    end
  end, { nargs = "?", desc = "Remotely connect to host via picker or command as argument." })
  vim.api.nvim_create_user_command("RemoteSSHFSEdit", function()
    picker.edit()
  end, {})
  vim.api.nvim_create_user_command("RemoteSSHFSReload", function()
    require("remote-sshfs.connections").reload()
  end, {})
  vim.api.nvim_create_user_command("RemoteSSHFSDisconnect", function()
    require("remote-sshfs.connections").unmount_host()
  end, {})
  vim.api.nvim_create_user_command("RemoteSSHFSFindFiles", function()
    picker.find_files {}
  end, {})
  vim.api.nvim_create_user_command("RemoteSSHFSLiveGrep", function()
    picker.live_grep {}
  end, {})
end

M.setup = function(config)
  local opts = config and vim.tbl_deep_extend("force", default_opts, config) or default_opts

  require("remote-sshfs.connections").setup(opts)
  require("remote-sshfs.ui").setup(opts)
  require("remote-sshfs.handler").setup(opts)
  require("remote-sshfs.log").setup(opts)

  M.setup_commands(opts)
end

return M
