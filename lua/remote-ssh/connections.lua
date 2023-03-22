local utils = require "remote-ssh.utils"
local hosts = {}

local M = {}

local sshfs_job_id = nil
-- local mountpoint = nil

M.init = function(config)
  -- M.init = function(connections_config)
  utils.setup_sshfs()
  hosts = utils.parse_hosts_from_config(config)
  vim.api.nvim_command "autocmd VimLeave * lua unmount_sshfs()"
  -- print(vim.inspect(hosts))
end

M.list_hosts = function()
  return hosts
end

M.mount_host = function(host)
  local home_dir = vim.fn.expand "$HOME"
  local remote_host = host["HostName"]

  -- Create a directory for the remote host if it doesn't exist
  local mount_dir = home_dir .. "/.sshfs/" .. remote_host
  if not vim.loop.fs_stat(mount_dir) then
    vim.loop.fs_mkdir(mount_dir, tonumber("700", 8), function(err)
      if err then
        print("Error creating SSHFS mount directory:", err)
        return
      end
    end)
  end

  -- Construct the SSHFS command
  local sshfs_cmd = "sshfs -f "
  -- TODO: Add a default value which is the current "user"
  local user = host["User"]

  if host["Port"] then
    sshfs_cmd = sshfs_cmd .. "-p " .. host["Port"] .. " "
  end

  sshfs_cmd = sshfs_cmd .. user .. "@" .. remote_host

  if host["Path"] then
    sshfs_cmd = sshfs_cmd .. ":" .. host["Path"] .. " "
  else
    sshfs_cmd = sshfs_cmd .. ":/home/" .. user .. "/ "
  end

  sshfs_cmd = sshfs_cmd .. mount_dir

  print(vim.inspect(sshfs_cmd))

  -- Mount the SSHFS directory
  -- mountpoint = mount_dir
  sshfs_job_id = vim.fn.jobstart(sshfs_cmd, {
    cwd = mount_dir,
    -- on_stdout = function(job_id, data, event)
      -- utils.change_directory(mount_dir)
      -- vim.defer_fn(utils.change_directory(mount_dir), 1000)
    -- end,
    on_exit = function(job_id, exit_code, event_type)
      sshfs_job_id = nil
      -- if exit_code ~= 0 then
      -- print "Error mounting SSHFS directory"

      -- else
      --   print("Mounted SSHFS directory for " .. remote_host .. " at " .. mount_dir)
      -- utils.change_directory(mount_dir)
      -- end
    end,
  })
  utils.change_directory(mount_dir)
  -- vim.defer_fn(utils.change_directory(mount_dir), 1000)
  -- utils.change_directory(mount_dir)
end

M.unmount_host = function()
  if sshfs_job_id then
    -- Kill the SSHFS process
    vim.fn.jobstop(sshfs_job_id)
  end
end

return M
