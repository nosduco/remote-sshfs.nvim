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
  local current_hosts = {}

  -- Iterate through all ssh config files in config
  for _, path in ipairs(ssh_configs) do
    -- Open the SSH config file
    local current_config = vim.fn.expand(path)
    if vim.fn.filereadable(current_config) == 1 then
      for line in io.lines(current_config) do
        -- Ignore comments and empty lines
        if line:sub(1, 1) ~= "#" and line:match "%S" then
          -- Check if the line is a Host entry
          local host_names = line:match "^%s*Host%s+(.+)$"
          if host_names then
            current_hosts = {}
            for host_name in host_names:gmatch "%S+" do
              table.insert(current_hosts, host_name)
              hosts[host_name] = { ["Config"] = path, ["Name"] = host_name }
            end
          else
            -- If the line is not a Host entry, but there are current hosts, add the line to their attributes
            if #current_hosts > 0 then
              local key, value = line:match "^%s*(%S+)%s+(.+)$"
              if key and value then
                for _, host in ipairs(current_hosts) do
                  hosts[host][key] = value
                end
              end
            end
          end
        end
      end
    end
  end
  return hosts
end

M.parse_host_from_command = function(command)
  local host = {}

  local port = command:match "%-p (%d+)"
  host["Port"] = port

  command = command:gsub("%s*%-p %d+%s*", "")

  local user, hostname, path = command:match "^([^@]+)@([^:]+):?(.*)$"
  if not user then
    hostname, path = command:match "^([^:]+):?(.*)$"
  end

  host["Name"] = hostname
  host["User"] = user
  host["Path"] = path

  return host
end

M.change_directory = function(path)
  -- Change the working directory of the Vim instance
  vim.fn.execute("cd " .. path)
  vim.notify("Directory changed to " .. path)
end

return M
