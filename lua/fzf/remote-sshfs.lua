local api = vim.api
local fn = vim.fn

-- Build virtualized host file from parsed hosts from plugin
local function build_host_preview(hosts, name)
  if name == "" or name == nil then
    return {}
  end

  local lines = {}
  local host = hosts[name]

  table.insert(lines, "# Config: " .. host["Config"])
  table.insert(lines, "Host " .. host["Name"])
  for key, value in pairs(host) do
    if key ~= "Name" and key ~= "Config" then
      table.insert(lines, string.format("\t%s %s", key, value))
    end
  end
  table.insert(lines, "")

  return table.concat(lines, "\n")
end

-- FZF action to select a host to connect to
local function connect(_)
  local connections = require("remote-sshfs.connections")
  local hosts = connections.list_hosts()
  
  -- Create a temporary file to store host previews
  local preview_file = vim.fn.tempname()
  local preview_data = {}
  
  -- Prepare preview data for each host
  local source = {}
  for hostname, _ in pairs(hosts) do
    table.insert(source, hostname)
    preview_data[hostname] = build_host_preview(hosts, hostname)
  end
  
  -- Write preview data to temp file
  local lines = {}
  for hostname, preview in pairs(preview_data) do
    table.insert(lines, hostname .. "\n" .. preview .. "\n---")
  end
  vim.fn.writefile(lines, preview_file)
  
  -- Create preview command that reads from the temp file
  local preview_cmd = string.format(
    'awk -v RS="---" "/^%s\\n/{print}" %s | tail -n +2',
    '{}',
    preview_file
  )
  
  -- Build fzf options string
  local opts = '--prompt="Connect to remote host> "'
    .. ' --preview="' .. preview_cmd .. '"'
    .. ' --preview-window="right:50%"'

  -- Create spec table for fzf
  local spec = {
    source = source,
    sink = function(selected)
      local host = hosts[selected]
      connections.connect(host)
      -- Clean up temp file
      vim.fn.delete(preview_file)
    end,
    options = opts
  }

  -- Run fzf with proper wrapping
  vim.fn['fzf#run'](vim.fn['fzf#wrap']('remote-sshfs', spec, 0))
end

-- FZF action to select ssh config file to edit
local function edit_config(_)
  local connections = require("remote-sshfs.connections")
  local ssh_configs = connections.list_ssh_configs()

  vim.fn['fzf#run'](vim.fn['fzf#wrap']({
    source = ssh_configs,
    sink = function(selected)
      vim.cmd('edit ' .. selected)
    end,
    options = {
      ['--prompt'] = 'Choose SSH config file to edit> ',
      ['--preview'] = 'cat {}',
      ['--preview-window'] = 'right:50%',
    }
  }))
end

local function command_exists_on_remote(command, server)
  local ssh_cmd = string.format('ssh %s "which %s"', server, command)
  local result = vim.fn.system(ssh_cmd)
  return result ~= ""
end

-- Remote find_files implementation
local function find_files(opts)
  opts = opts or {}
  local connections = require("remote-sshfs.connections")

  if not connections.is_connected() then
    vim.notify("You are not currently connected to a remote host.")
    return
  end

  local mount_point = opts.mount_point or connections.get_current_mount_point()
  local current_host = connections.get_current_host()

  -- Build the find command
  local find_command = (function()
    if opts.find_command then
      if type(opts.find_command) == "function" then
        return opts.find_command(opts)
      end
      return opts.find_command
    elseif command_exists_on_remote("rg", current_host["Name"]) then
      return { "ssh", current_host["Name"], "-C", "rg", "--files", "--color", "never" }
    elseif command_exists_on_remote("fd", current_host["Name"]) then
      return { "ssh", current_host["Name"], "fd", "--type", "f", "--color", "never" }
    elseif command_exists_on_remote("fdfind", current_host["Name"]) then
      return { "ssh", current_host["Name"], "fdfind", "--type", "f", "--color", "never" }
    elseif command_exists_on_remote("where", current_host["Name"]) then
      return { "ssh", current_host["Name"], "where", "/r", ".", "*" }
    end
  end)()

  if not find_command then
    vim.notify("Remote host does not support any available find commands (rg, fd, fdfind, where).")
    return
  end

  -- Adapt command based on options
  local command = find_command[3]
  if command == "fd" or command == "fdfind" or command == "rg" then
    if opts.hidden then
      table.insert(find_command, "--hidden")
    end
    if opts.no_ignore then
      table.insert(find_command, "--no-ignore")
    end
    if opts.follow then
      table.insert(find_command, "-L")
    end
  end

  -- Create FZF options
  local fzf_opts = {
    source = table.concat(find_command, " "),
    sink = function(selected)
      vim.cmd('edit ' .. mount_point .. '/' .. selected)
    end,
    options = {
      ['--prompt'] = 'Remote Find Files> ',
      ['--preview'] = string.format('cat %s/{}', mount_point),
      ['--preview-window'] = 'right:50%',
    }
  }

  vim.fn['fzf#run'](vim.fn['fzf#wrap'](fzf_opts))
end

-- Remote live_grep implementation
local function live_grep(opts)
  opts = opts or {}
  local connections = require("remote-sshfs.connections")

  if not connections.is_connected() then
    vim.notify("You are not currently connected to a remote host.")
    return
  end

  local current_host = connections.get_current_host()
  local mount_point = opts.mount_point or connections.get_current_mount_point()

  -- Build the rg command
  local rg_command = {
    "ssh",
    current_host["Name"],
    "-C",
    "rg",
    "--column",
    "--line-number",
    "--no-heading",
    "--color=always",
    "--smart-case",
  }

  if opts.type_filter then
    table.insert(rg_command, "--type=" .. opts.type_filter)
  end

  if opts.glob_pattern then
    if type(opts.glob_pattern) == "string" then
      table.insert(rg_command, "--glob=" .. opts.glob_pattern)
    elseif type(opts.glob_pattern) == "table" then
      for _, pattern in ipairs(opts.glob_pattern) do
        table.insert(rg_command, "--glob=" .. pattern)
      end
    end
  end

  -- Create FZF options
  local fzf_opts = {
    source = table.concat(rg_command, " "),
    sink = function(selected)
      -- Parse the selection (format: file:line:col:text)
      local parts = vim.split(selected, ":")
      local file = parts[1]
      local line = tonumber(parts[2])
      local col = tonumber(parts[3])
      
      -- Open the file at the specific location
      vim.cmd('edit ' .. mount_point .. '/' .. file)
      vim.api.nvim_win_set_cursor(0, {line, col - 1})
    end,
    options = {
      ['--prompt'] = 'Remote Live Grep> ',
      ['--preview'] = string.format('bat --style=numbers --color=always %s/$(echo {} | cut -d: -f1)', mount_point),
      ['--preview-window'] = 'right:50%',
      ['--delimiter'] = ':',
      ['--nth'] = '4..',
    }
  }

  vim.fn['fzf#run'](vim.fn['fzf#wrap'](fzf_opts))
end

-- Initialize plugin
local function setup()
  -- Create user commands
  vim.api.nvim_create_user_command('RemoteConnect', function(opts)
    connect(opts)
  end, {})

  vim.api.nvim_create_user_command('RemoteEdit', function(opts)
    edit_config(opts)
  end, {})

  vim.api.nvim_create_user_command('RemoteFiles', function(opts)
    find_files(opts)
  end, {})

  vim.api.nvim_create_user_command('RemoteGrep', function(opts)
    live_grep(opts)
  end, {})
end

return {
  setup = setup,
  connect = connect,
  edit_config = edit_config,
  find_files = find_files,
  live_grep = live_grep,
}
