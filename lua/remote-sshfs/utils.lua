local log = require "remote-sshfs.log"

local M = {}

M.setup_sshfs = function(config)
  local sshfs_folder = config.mounts.base_dir
  if not vim.loop.fs_stat(sshfs_folder) then
    vim.loop.fs_mkdir(sshfs_folder, tonumber("700", 8), function(err)
      if err then
        vim.notify("Error creating mount base dir (" .. sshfs_folder .. "):", err)
        return
      end
    end)
  end
end

M.file_exists = function(path)
  local _, error = vim.loop.fs_stat(path)
  return error == nil
end

M.setup_mount_dir = function(mount_dir, callback)
  log.line("util", "Setting up mount directory " .. mount_dir)
  if not M.file_exists(mount_dir) then
    log.line("util", "Creating mount directory " .. mount_dir)
    local success = vim.loop.fs_mkdir(mount_dir, tonumber("700", 8))
    if not success then
      vim.notify("Error creating mount directory (" .. mount_dir .. ").")
    else
      callback()
    end
  else
    callback()
  end
end

M.cleanup_mount_dir = function(mount_dir, callback)
  log.line("util", "Cleaning up mount directory " .. mount_dir)
  if M.file_exists(mount_dir) then
    log.line("util", "Removing mount directory " .. mount_dir)
    local success = vim.loop.fs_rmdir(mount_dir)
    if not success then
      vim.notify("Error cleaning up mount directory (" .. mount_dir .. ").")
    else
      callback()
    end
  else
    callback()
  end
end

M.parse_hosts_from_configs = function(ssh_configs)
  local hosts = {}
  local current_host = nil

  -- Iterate through all ssh config files in config
  for _, path in ipairs(ssh_configs) do
    -- Open the SSH config file
    local current_config = vim.fn.expand(path)
    for line in io.lines(current_config) do
      -- Ignore comments and empty lines
      if line:sub(1, 1) ~= "#" and line:match "%S" then
        -- Check if the line is a Host entry
        local host_name = line:match "^%s*Host%s+(.+)$"
        if host_name then
          current_host = host_name
          hosts[current_host] = {}
          hosts[current_host]["Config"] = path
          hosts[current_host]["Name"] = current_host
        else
          -- If the line is not a Host entry, but there is a current host, add the line to its attributes
          if current_host then
            local key, value = line:match "^%s*(%S+)%s+(.+)$"
            if key and value then
              hosts[current_host][key] = value
            end
          end
        end
      end
    end
  end
  return hosts
end

M.change_directory = function(path)
  -- Change the working directory of the Vim instance
  vim.fn.execute("cd " .. path)
  vim.notify("Directory changed to " .. path)
end

return M
