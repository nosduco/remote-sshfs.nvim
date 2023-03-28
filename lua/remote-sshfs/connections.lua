local utils = require "remote-sshfs.utils"
local handler = require "remote-sshfs.handler"

local config = {}
local hosts = {}
local ssh_configs = {}
local sshfs_job_id = nil

local M = {}

M.setup = function(opts)
  config = opts
  utils.setup_sshfs(config)
  ssh_configs = config.connections.ssh_configs
  hosts = utils.parse_hosts_from_configs(ssh_configs)
end

M.list_hosts = function()
  return hosts
end

M.list_ssh_configs = function()
  return ssh_configs
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
    utils.prompt_yes_no(prompt, function(item_short)
      utils.clear_prompt()
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
  -- Setup new connection
  local remote_host = host["Name"]

  -- TODO: Handle SSH CONFIG LogLevel, Compression, IdentityFile, Wild card hosts.

  -- Construct the SSHFS command
  local sshfs_cmd = "sshfs -o LOGLEVEL=VERBOSE -o ConnectTimeout=5 "

  if config.mounts.unmount_on_exit then
    sshfs_cmd = sshfs_cmd .. "-f "
  end

  if host["Port"] then
    sshfs_cmd = sshfs_cmd .. "-p " .. host["Port"] .. " "
  end

  local user = vim.fn.expand "$USERNAME"
  if host["User"] then
    user = host["User"]
  end
  sshfs_cmd = sshfs_cmd .. user .. "@" .. remote_host

  if host["Path"] then
    sshfs_cmd = sshfs_cmd .. ":" .. host["Path"] .. " "
  else
    sshfs_cmd = sshfs_cmd .. ":/home/" .. user .. "/ "
  end

  sshfs_cmd = sshfs_cmd .. mount_dir

  local function start_job()
    local sshfs_cmd_local = sshfs_cmd

    -- If password required
    if ask_pass then
      local password = vim.fn.inputsecret "Enter password for host: "
      sshfs_cmd_local = "echo " .. password .. " | " .. sshfs_cmd .. " -o password_stdin"
    end

    print("Connecting to host (" .. remote_host .. ")...")
    local skip_clean = false
    sshfs_job_id = vim.fn.jobstart(sshfs_cmd_local, {
      cwd = mount_dir,
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
        end)
      end,
    })
  end
  start_job()
end

M.unmount_host = function()
  if sshfs_job_id then
    -- Kill the SSHFS process
    vim.fn.jobstop(sshfs_job_id)
  end
end

return M
