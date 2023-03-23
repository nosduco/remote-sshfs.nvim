local M = {}

M.parse_hosts_from_ssh_config = function(config)
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

return M
