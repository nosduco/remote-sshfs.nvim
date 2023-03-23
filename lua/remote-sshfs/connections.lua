local utils = require "remote-sshfs.utils"
local handlers = require "remote-sshfs.handler"

local hosts = {}
local config = {}
local sshfs_job_id = nil

local M = {}

M.setup = function(opts)
  config = opts
  utils.setup_sshfs(config)
  hosts = utils.parse_hosts_from_config(config)
end

M.list_hosts = function()
  return hosts
end

M.mount_host = function(host)
  -- Setup new connection
  local remote_host = host["HostName"]

  -- Check confirm
  -- TODO: Finish this
  -- if config.ui.confirm.connect then
  --   local prompt = "Connect to remote host (" .. remote_host .. ")?"
  --
  --   utils.check_confirm("Connect to remote host (" .. remote_host .. ")?") then
  -- -- if config.ui.confirm.connect and not utils.check_confirm("Connect to remote host (" .. remote_host .. ") [Y/n]?") then
  --   return
  -- end

  -- If already connected, disconnect
  if sshfs_job_id then
    -- Kill the SSHFS process
    vim.fn.jobstop(sshfs_job_id)
  end

  -- Create a directory for the remote host if it doesn't exist
  local mount_dir = config.mounts.base_dir .. remote_host
  if not vim.loop.fs_stat(mount_dir) then
    vim.loop.fs_mkdir(mount_dir, tonumber("700", 8), function(err)
      if err then
        print("Error creating SSHFS mount directory:", err)
        return
      end
    end)
  end

  -- Construct the SSHFS command
  local sshfs_cmd = "sshfs -o LOGLEVEL=VERBOSE "

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

  -- print(vim.inspect(sshfs_cmd))

  local function start_job(ask_pass)
    local sshfs_cmd_local = sshfs_cmd
    -- Kill current job (if one exists)
    if sshfs_job_id then
      -- Kill the SSHFS process
      vim.fn.jobstop(sshfs_job_id)
    end

    if ask_pass then
      local password = vim.fn.inputsecret "Enter password for host: "
      sshfs_cmd_local = "echo " .. password .. " | " .. sshfs_cmd .. " -o password_stdin"
    end

    print "Connecting to host..."
    -- print(vim.inspect(sshfs_cmd_local))

    local debug = ""
    sshfs_job_id = vim.fn.jobstart(sshfs_cmd_local, {
      cwd = mount_dir,
      on_stderr = function(_, data)
        local output = table.concat(data, "\n")
        if string.match(output, "ssh_askpass") and not ask_pass then
          -- SSHFS tried to ask for password, prompt for password and rerun (if not been asked before)
          start_job(true)
        elseif string.match(output, "connection refused") then
          print "Connection to host refused. Please check your ssh configuration."
        elseif string.match(output, "denied") then
          print "Failed to connect to host: permission denied"
        elseif string.match(output, "Authenticated") then
          -- Succesfully connected
          print "Connected to host succesfully."
          if config.actions.on_connect.change_dir then
            if config.ui.confirm.change_dir then
              -- local confirm_change_dir = vim.fn.input "Change current directory to remote server [Y/n]?"
              local prompt = "Change current directory to remote server?"
              utils.prompt_yes_no(prompt, function(item_short)
                utils.clear_prompt()
                if item_short == "y" then
                  utils.change_directory(mount_dir)
                end
              end)
            else
              utils.change_directory(mount_dir)
            end
          end
          if config.actions.on_connect.find_files then
            utils.find_files()
          end
        end
        -- TODO: Catch bad mountpoint
        -- debug = debug .. output
        -- print(vim.inspect(debug))
      end,
      on_exit = function()
        sshfs_job_id = nil
        -- TODO: Clean mount folders via (config.actions.on_disconnect.clean_mount_folders)
      end,
    })
  end

  start_job(false)
end

M.unmount_host = function()
  if sshfs_job_id then
    -- Kill the SSHFS process
    vim.fn.jobstop(sshfs_job_id)
  end
end

return M
