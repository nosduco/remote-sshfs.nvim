local M = {}

local default_opts = {
  connections = {
    ssh_configs = {
      vim.fn.expand "$HOME" .. "/.ssh/config",
      "/etc/ssh/ssh_config",
      -- "/path/to/custom/ssh_config"
    },
    ssh_known_hosts = vim.fn.expand "$HOME" .. "/.ssh/known_hosts",
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
    picker = nil, -- "telescope", "snacks", or nil (auto-detect)
  },
  log = {
    enabled = false,
    truncate = false,
    types = {
      all = false,
      util = false,
      handler = false,
      sshfs = false,
    },
  },
}

local utils = require "remote-sshfs.utils"
local CallbackList = utils.CallbackList

M.callback = {
  on_connect_success = CallbackList:new(),
}

--- Resolve the picker backend to use.
--- Returns "telescope" or "snacks".
local function resolve_picker()
  local picker = M.config and M.config.ui and M.config.ui.picker
  if picker then
    return picker
  end

  -- Auto-detect: prefer snacks if available, fall back to telescope
  if pcall(require, "snacks") then
    return "snacks"
  elseif pcall(require, "telescope") then
    return "telescope"
  end

  return "telescope"
end

--- Call a picker action by name, routing to the configured backend.
--- @param action string One of "connect", "edit", "find_files", "live_grep"
--- @param opts table|nil Options forwarded to the picker
local function picker_action(action, opts)
  local backend = resolve_picker()

  if backend == "snacks" then
    local snacks_pickers = require "remote-sshfs.pickers.snacks"
    snacks_pickers[action](opts)
  else
    local telescope_map = {
      connect = "connect",
      edit = "edit",
      find_files = "find_files",
      live_grep = "live_grep",
    }
    require("telescope").extensions["remote-sshfs"][telescope_map[action]](opts)
  end
end

M.setup_commands = function()
  -- Create commands to connect/edit/reload/disconnect/find_files/live_grep
  vim.api.nvim_create_user_command("RemoteSSHFSConnect", function(opts)
    if opts.args and opts.args ~= "" then
      local host = require("remote-sshfs.utils").parse_host_from_command(opts.args)
      require("remote-sshfs.connections").connect(host)
    else
      picker_action("connect")
    end
  end, {
    nargs = "?",
    desc = "Remotely connect to host via picker or command as argument.",
    complete = function()
      return vim.tbl_keys(require("remote-sshfs.connections").list_hosts())
    end,
  })
  vim.api.nvim_create_user_command("RemoteSSHFSEdit", function()
    picker_action("edit")
  end, {})
  vim.api.nvim_create_user_command("RemoteSSHFSReload", function()
    require("remote-sshfs.connections").reload()
  end, {})
  vim.api.nvim_create_user_command("RemoteSSHFSDisconnect", function()
    require("remote-sshfs.connections").unmount_host()
  end, {})
  vim.api.nvim_create_user_command("RemoteSSHFSFindFiles", function()
    picker_action("find_files", {})
  end, {})
  vim.api.nvim_create_user_command("RemoteSSHFSLiveGrep", function()
    picker_action("live_grep", {})
  end, {})
end

M.setup = function(config)
  local opts = config and vim.tbl_deep_extend("force", default_opts, config) or default_opts

  M.config = opts

  require("remote-sshfs.connections").setup(opts)
  require("remote-sshfs.ui").setup(opts)
  require("remote-sshfs.handler").setup(opts)
  require("remote-sshfs.log").setup(opts)

  M.setup_commands()
end

return M
