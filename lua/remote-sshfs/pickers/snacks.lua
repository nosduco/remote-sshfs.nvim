local log = require "remote-sshfs.log"

local M = {}

-- Build virtualized host file from parsed hosts
local function build_host_preview(hosts, name)
  if name == "" or name == nil then
    return {}
  end

  local lines = {}
  local host = hosts[name]
  if not host then
    return {}
  end

  table.insert(lines, "# Config: " .. host["Config"])
  table.insert(lines, "Host " .. host["Name"])
  for key, value in pairs(host) do
    if key ~= "Name" and key ~= "Config" then
      table.insert(lines, string.format("\t%s %s", key, value))
    end
  end
  table.insert(lines, "")

  return lines
end

-- Cache for remote command availability
local command_exists_cache = {}

local function command_exists_on_remote(command, server)
  local key = server .. ":" .. command
  if command_exists_cache[key] ~= nil then
    return command_exists_cache[key]
  end
  local ssh_cmd = string.format('ssh %s "which %s"', server, command)
  vim.fn.system(ssh_cmd)
  local exists = (vim.v.shell_error == 0)
  command_exists_cache[key] = exists
  return exists
end

-- Cache per-host computed find command to avoid repeated ssh which calls
local _find_command_cache = {}
local function get_find_command_for_host(server)
  if _find_command_cache[server] ~= nil then
    return _find_command_cache[server]
  end
  local cmd = nil
  if command_exists_on_remote("rg", server) then
    cmd = { "ssh", server, "-C", "rg", "--files", "--color", "never" }
  elseif command_exists_on_remote("fd", server) then
    cmd = { "ssh", server, "fd", "--type", "f", "--color", "never" }
  elseif command_exists_on_remote("fdfind", server) then
    cmd = { "ssh", server, "fdfind", "--type", "f", "--color", "never" }
  elseif command_exists_on_remote("where", server) then
    cmd = { "ssh", server, "where", "/r", ".", "*" }
  end
  _find_command_cache[server] = cmd
  return cmd
end

-- Clears cached remote-find commands and existence checks
function M.clear_cache()
  command_exists_cache = {}
  _find_command_cache = {}
end

--- Picker: connect to a remote host
function M.connect(opts)
  local Snacks = require "snacks"
  local connections = require "remote-sshfs.connections"
  local hosts = connections.list_hosts()
  local host_names = vim.tbl_keys(hosts)

  local items = {}
  for i, name in ipairs(host_names) do
    items[i] = {
      idx = i,
      text = name,
      name = name,
    }
  end

  Snacks.picker.pick(vim.tbl_deep_extend("force", {
    title = "Connect to remote host",
    items = items,
    format = "text",
    preview = function(ctx)
      if not ctx.item then
        return
      end
      local lines = build_host_preview(hosts, ctx.item.name)
      vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, lines)
      vim.bo[ctx.buf].filetype = "sshconfig"
      return true
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      local host = hosts[item.name]
      connections.connect(host)
    end,
    layout = "vertical",
  }, opts or {}))
end

--- Picker: edit SSH config file
function M.edit(opts)
  local Snacks = require "snacks"
  local connections = require "remote-sshfs.connections"
  local ssh_configs = connections.list_ssh_configs()

  local items = {}
  for i, config_path in ipairs(ssh_configs) do
    items[i] = {
      idx = i,
      text = config_path,
      file = config_path,
    }
  end

  Snacks.picker.pick(vim.tbl_deep_extend("force", {
    title = "Choose SSH config file to edit",
    items = items,
    format = "text",
    preview = function(ctx)
      if not ctx.item or not ctx.item.file then
        return
      end

      local file_path = ctx.item.file
      local ok, lines = pcall(vim.fn.readfile, file_path)
      if not ok or not lines then
        return
      end

      vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, lines)
      vim.bo[ctx.buf].filetype = "sshconfig"
      return true
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      vim.cmd("edit " .. vim.fn.fnameescape(item.file))
    end,
    layout = "vertical",
  }, opts or {}))
end

--- Picker: remote find_files
function M.find_files(opts)
  local Snacks = require "snacks"
  local connections = require "remote-sshfs.connections"

  -- Check that a connection exists
  if not connections.is_connected() then
    vim.notify "You are not currently connected to a remote host."
    return
  end

  opts = opts or {}
  local mount_point = opts.mount_point or connections.get_current_mount_point()
  local current_host = connections.get_current_host()

  local find_command
  if opts.find_command then
    if type(opts.find_command) == "function" then
      find_command = opts.find_command(opts)
    else
      find_command = opts.find_command
    end
  else
    find_command = get_find_command_for_host(current_host["Name"])
  end

  if not find_command then
    vim.notify "Remote host does not support any available find commands (rg, fd, fdfind, where)."
    return
  end

  -- Deep copy to avoid mutating the cached command
  find_command = vim.deepcopy(find_command)

  -- Apply additional options to find command
  local command = find_command[3]
  local hidden = opts.hidden
  local no_ignore = opts.no_ignore
  local no_ignore_parent = opts.no_ignore_parent
  local follow = opts.follow
  local search_dirs = opts.search_dirs
  local search_file = opts.search_file

  if command == "fd" or command == "fdfind" or command == "rg" then
    if hidden then
      find_command[#find_command + 1] = "--hidden"
    end
    if no_ignore then
      find_command[#find_command + 1] = "--no-ignore"
    end
    if no_ignore_parent then
      find_command[#find_command + 1] = "--no-ignore-parent"
    end
    if follow then
      find_command[#find_command + 1] = "-L"
    end
    if search_file then
      if command == "rg" then
        find_command[#find_command + 1] = "-g"
        find_command[#find_command + 1] = "*" .. search_file .. "*"
      else
        find_command[#find_command + 1] = search_file
      end
    end
    if search_dirs then
      if command ~= "rg" and not search_file then
        find_command[#find_command + 1] = "."
      end
      vim.list_extend(find_command, search_dirs)
    end
  elseif command == "find" then
    if not hidden then
      local extra = { "-not", "-path", "*/.*" }
      for _, v in ipairs(extra) do
        table.insert(find_command, v)
      end
    end
    if follow then
      table.insert(find_command, 5, "-L")
    end
    if search_file then
      table.insert(find_command, "-name")
      table.insert(find_command, "*" .. search_file .. "*")
    end
    if search_dirs then
      table.remove(find_command, 5)
      for _, v in pairs(search_dirs) do
        table.insert(find_command, 5, v)
      end
    end
  end

  -- Extract cmd and args from the find_command table
  local cmd = find_command[1]
  local args = {}
  for i = 2, #find_command do
    args[#args + 1] = find_command[i]
  end

  Snacks.picker.pick(vim.tbl_deep_extend("force", {
    title = "Remote Find Files",
    finder = function(ctx)
      local proc = require "snacks.picker.source.proc"
      return proc.proc({
        cmd = cmd,
        args = args,
        ---@param item snacks.picker.finder.Item
        transform = function(item)
          local filename = item.text
          if not filename or filename == "" then
            return false
          end
          -- Strip leading ./ if present
          if filename:sub(1, 2) == "./" then
            filename = filename:sub(3)
          end
          item.file = mount_point .. filename
          item.text = filename
          return item
        end,
      }, ctx)
    end,
    format = function(item)
      local ret = {}
      ret[#ret + 1] = { item.text .. "\n", "Normal" }
      return ret
    end,
    preview = "file",
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      vim.cmd("edit " .. vim.fn.fnameescape(item.file))
    end,
    layout = "telescope",
  }, opts or {}))
end

--- Picker: remote live_grep
function M.live_grep(opts)
  local Snacks = require "snacks"
  local connections = require "remote-sshfs.connections"

  -- Check that a connection exists
  if not connections.is_connected() then
    vim.notify "You are not currently connected to a remote host."
    return
  end

  opts = opts or {}
  local current_host = connections.get_current_host()
  local mount_point = opts.mount_point or connections.get_current_mount_point()
  local search_dirs = opts.search_dirs

  -- Build base rg arguments for grep
  local base_args = {
    current_host["Name"],
    "-C",
    "rg",
    "--color=never",
    "--no-heading",
    "--with-filename",
    "--line-number",
    "--column",
    "--smart-case",
  }

  -- Apply additional args
  local additional_args = {}
  if opts.additional_args ~= nil then
    if type(opts.additional_args) == "function" then
      additional_args = opts.additional_args(opts)
    elseif type(opts.additional_args) == "table" then
      additional_args = opts.additional_args
    end
  end

  if opts.type_filter then
    additional_args[#additional_args + 1] = "--type=" .. opts.type_filter
  end

  if type(opts.glob_pattern) == "string" then
    additional_args[#additional_args + 1] = "--glob=" .. opts.glob_pattern
  elseif type(opts.glob_pattern) == "table" then
    for i = 1, #opts.glob_pattern do
      additional_args[#additional_args + 1] = "--glob=" .. opts.glob_pattern[i]
    end
  end

  for _, arg in ipairs(additional_args) do
    base_args[#base_args + 1] = arg
  end

  Snacks.picker.pick(vim.tbl_deep_extend("force", {
    title = "Remote Live Grep",
    live = true,
    finder = function(ctx)
      local search = ctx.filter and ctx.filter.search or ctx.search or ""
      if not search or search == "" then
        return function() end
      end

      -- Build the full argument list: base_args + "--" + pattern + search_dirs + "."
      local args = vim.deepcopy(base_args)
      args[#args + 1] = "--"
      args[#args + 1] = search
      if search_dirs then
        for _, dir in ipairs(search_dirs) do
          args[#args + 1] = dir
        end
      end
      args[#args + 1] = "."

      local proc = require "snacks.picker.source.proc"
      return proc.proc({
        cmd = "ssh",
        args = args,
        ---@param item snacks.picker.finder.Item
        transform = function(item)
          local line = item.text
          if not line or line == "" then
            return false
          end

          -- Parse rg output: filename:line:col:text
          local filename, lnum, col, text = line:match "^(.+):(%d+):(%d+):(.*)$"
          if not filename then
            return false
          end

          -- Strip leading ./ if present
          if filename:sub(1, 2) == "./" then
            filename = filename:sub(3)
          end

          item.file = mount_point .. filename
          item.text = line
          item.pos = { tonumber(lnum), tonumber(col) - 1 }
          item.line = text
          item.filename = filename

          return item
        end,
      }, ctx)
    end,
    format = function(item)
      local ret = {}
      local filename = item.filename or ""
      local lnum = item.pos and item.pos[1] or ""
      local col = item.pos and (item.pos[2] + 1) or ""
      local text = item.line or ""

      ret[#ret + 1] = { filename, "SnacksPickerFile" }
      ret[#ret + 1] = { ":", "SnacksPickerDelim" }
      ret[#ret + 1] = { tostring(lnum), "SnacksPickerRow" }
      ret[#ret + 1] = { ":", "SnacksPickerDelim" }
      ret[#ret + 1] = { tostring(col), "SnacksPickerCol" }
      ret[#ret + 1] = { ":", "SnacksPickerDelim" }
      ret[#ret + 1] = { text .. "\n", "Normal" }
      return ret
    end,
    preview = "file",
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      vim.cmd("edit " .. vim.fn.fnameescape(item.file))
      if item.pos then
        pcall(vim.api.nvim_win_set_cursor, 0, { item.pos[1], item.pos[2] })
        vim.cmd "normal! zz"
      end
    end,
    layout = "telescope",
  }, opts or {}))
end

return M
