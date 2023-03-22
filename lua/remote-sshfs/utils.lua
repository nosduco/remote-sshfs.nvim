-- local config = require "remote-sshfs.config"
-- local a = require "plenary.async"

local M = {}

M.setup_sshfs = function(config)
  local sshfs_folder = config.mounts.base_dir
  if not vim.loop.fs_stat(sshfs_folder) then
    vim.loop.fs_mkdir(sshfs_folder, tonumber("700", 8), function(err)
      if err then
        print("Error creating mount base dir (" .. sshfs_folder .. "):", err)
        return
      end
    end)
  end
end

M.parse_hosts_from_config = function(config)
  -- Open the SSH config file
  local ssh_config = vim.fn.expand(config.connections.ssh_config_path)

  local hosts = {}
  local current_host = nil

  for line in io.lines(ssh_config) do
    -- Ignore comments and empty lines
    if line:sub(1, 1) ~= "#" and line:match "%S" then
      -- Check if the line is a Host entry
      local host_name = line:match "^%s*Host%s+(.+)$"
      if host_name then
        current_host = host_name
        hosts[current_host] = {}
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

  return hosts
end

M.change_directory = function(path)
  -- Change the working directory of the Vim instance
  vim.fn.execute("cd " .. path)

  -- Update the nvim-tree to reflect the new directory
  -- if vim.api.nvim_buf_get_name(0):match "nvim_tree" then
  --   require("nvim-tree").change_dir(path)
  -- end
  -- require("nvim-tree.api").tree.change_root(path)
  -- vim.cmd("NvimTreeRefresh")
end

M.find_files = function()
  vim.cmd(":Telescope find_files")
end

return M
