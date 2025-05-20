local utils = require "remote-sshfs.utils"
local ui = require "remote-sshfs.ui"
local handler = require "remote-sshfs.handler"

local config = {}
local hosts = {}
local ssh_configs = {}
local sshfs_args = {}

-- Current connection
local sshfs_job_id = nil
local mount_point = nil
local current_host = nil

local M = {}

M.setup = function(opts)
  config = opts
  utils.setup_sshfs(config)
  ssh_configs = config.connections.ssh_configs
  sshfs_args = config.connections.sshfs_args
  hosts = utils.parse_hosts_from_configs(ssh_configs)
end

M.is_connected = function()
  if sshfs_job_id and mount_point and current_host then
    return true
  end
  return false
end

M.list_hosts = function()
  return hosts
end

M.list_ssh_configs = function()
  return ssh_configs
end

M.get_current_host = function()
  return current_host
end

M.get_current_mount_point = function()
  return mount_point
end

M.reload = function()
  hosts = utils.parse_hosts_from_configs(ssh_configs)
  vim.notify "Reloaded!"
end

M.connect = function(host)
  -- Initialize host variables
  local remote_host = host["Name"]
  if config.ui.confirm.connect then
    local prompt = "Connect to remote host (" .. remote_host .. ")?"
    ui.prompt_yes_no(prompt, function(item_short)
      ui.clear_prompt()
      if item_short == "y" then
        M.init_host(host)
      end
    end)
  else
    M.init_host(host)
  end
end

M.init_host = function(host, ask_pass)
  -- If already connected, disconnect
  if sshfs_job_id then
    -- Kill the SSHFS process
    vim.fn.jobstop(sshfs_job_id)
  end

  -- Create/confirm mount directory
  local remote_host = host["Name"]
  local mount_dir = config.mounts.base_dir .. remote_host

  if not ask_pass then
    utils.setup_mount_dir(mount_dir, function()
      M.mount_host(host, mount_dir, ask_pass)
    end)
  else
    M.mount_host(host, mount_dir, ask_pass)
  end
end

M.mount_host = function(host, mount_dir, ask_pass)
  -- Ensure sshfs is available
  if vim.fn.executable("sshfs") == 0 then
    vim.api.nvim_err_writeln("[remote-sshfs] 'sshfs' not found. Please install sshfs to use remote-sshfs.")
    return
  end
  -- Setup new connection
  local remote_host = host["Name"]

  -- Build SSHFS command as argument list to avoid shell quoting issues
  local cmd = { "sshfs" }
  -- Verbose logging
  table.insert(cmd, "-o")
  table.insert(cmd, "LOGLEVEL=VERBOSE")
  -- Custom SSHFS args
  for _, value in ipairs(sshfs_args) do
    for _, part in ipairs(vim.split(value, "%s+")) do
      table.insert(cmd, part)
    end
  end
  -- Run in foreground to allow graceful unmount if configured
  if config.mounts.unmount_on_exit then
    table.insert(cmd, "-f")
  end
  -- Remote port
  if host["Port"] then
    table.insert(cmd, "-p")
    table.insert(cmd, host["Port"])
  end
  -- Password via stdin support
  if ask_pass then
    table.insert(cmd, "-o")
    table.insert(cmd, "password_stdin")
  end
  -- Build remote spec: [user@]host[:path]
  local spec = remote_host
  if host["User"] then
    spec = host["User"] .. "@" .. spec
  end
  spec = spec .. ":" .. (host["Path"] or "")
  table.insert(cmd, spec)
  -- Mount point
  table.insert(cmd, mount_dir)

  local function start_job()
    vim.notify("Connecting to host (" .. remote_host .. ")...")
    local skip_clean = false
    mount_point = mount_dir .. "/"
    current_host = host
    -- Spawn SSHFS without a shell
    sshfs_job_id = vim.fn.jobstart(cmd, {
      on_stdout = function(_, data)
        handler.sshfs_wrapper(data, mount_dir, function(event)
          if event == "ask_pass" then
            skip_clean = true
            M.init_host(host, true)
          end
        end)
      end,
      on_stderr = function(_, data)
        handler.sshfs_wrapper(data, mount_dir, function(event)
          if event == "ask_pass" then
            skip_clean = true
            M.init_host(host, true)
          end
        end)
      end,
      on_exit = function(_, _, data)
        handler.on_exit_handler(data, mount_dir, skip_clean, function()
          sshfs_job_id = nil
          mount_point = nil
          current_host = nil
        end)
      end,
    })
    -- If using password, send it on stdin
    if ask_pass then
      local password = vim.fn.inputsecret "Enter password for host: "
      vim.fn.chansend(sshfs_job_id, password .. "\n")
    end
  end
  start_job()
end

M.unmount_host = function()
  -- Stop the SSHFS job if running
  if sshfs_job_id then
    vim.fn.jobstop(sshfs_job_id)
  end
  -- Ensure the mount is unmounted on disk
  if mount_point then
    local target = mount_point:gsub("/$", "")
    -- Try Linux fusermount
    vim.fn.system({"fusermount", "-u", target})
    if vim.v.shell_error ~= 0 then
      -- Fallback to generic umount
      vim.fn.system({"umount", target})
    end
    sshfs_job_id = nil
    mount_point = nil
    current_host = nil
  end
end

return M
