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

M.setup_mount_dir = function(mount_dir, callback)
  if not vim.loop.fs_stat(mount_dir) then
    -- TODO: correct perms
    local success = vim.loop.fs_mkdir(mount_dir, tonumber("700", 8))
    if not success then
      print("Error creating mount directory (" .. mount_dir .. ").")
    else
      callback()
    end
  else
    callback()
  end
end

M.parse_hosts_from_configs = function(config)
  local hosts = {}
  local current_host = nil

  -- Iterate through all ssh config files in config
  for i, path in ipairs(config.connections.ssh_configs) do
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

M.prompt = function(prompt_input, prompt_select, items_short, items_long, callback)
  local function format_item(short)
    for i, s in ipairs(items_short) do
      if short == s then
        return items_long[i]
      end
    end
  end

  if M.select_prompts then
    vim.ui.select(items_short, { prompt = prompt_select, format_item = format_item }, function(item_short)
      callback(item_short)
    end)
  else
    vim.ui.input({ prompt = prompt_input }, function(item_short)
      callback(item_short)
    end)
  end
end

M.prompt_yes_no = function(prompt_input, callback)
  return M.prompt(prompt_input .. " y/n: ", prompt_input, { "y", "n" }, { "Yes", "No" }, callback)
end

M.clear_prompt = function()
  if vim.opt.cmdheight._value ~= 0 then
    vim.cmd "normal! :"
  end
end

M.change_directory = function(path)
  -- Change the working directory of the Vim instance
  vim.fn.execute("cd " .. path)
end

M.find_files = function()
  vim.cmd ":Telescope find_files"
end

M.setup = function(opts)
  M.select_prompts = opts.select_prompts
end

return M
