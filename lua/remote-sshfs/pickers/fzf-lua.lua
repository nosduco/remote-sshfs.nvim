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
  local fzf_lua = require "fzf-lua"
  local builtin = require "fzf-lua.previewer.builtin"
  local connections = require "remote-sshfs.connections"
  local hosts = connections.list_hosts()
  local host_names = vim.tbl_keys(hosts)

  -- Custom previewer for SSH host config
  local HostPreviewer = builtin.base:extend()

  function HostPreviewer:new(o, fzf_opts, fzf_win)
    HostPreviewer.super.new(self, o, fzf_opts, fzf_win)
    setmetatable(self, HostPreviewer)
    return self
  end

  function HostPreviewer:populate_preview_buf(entry_str)
    local tmpbuf = self:get_tmp_buffer()
    local name = entry_str:match "^%s*(.-)%s*$"
    local lines = build_host_preview(hosts, name)
    vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, lines)
    vim.bo[tmpbuf].filetype = "sshconfig"
    self:set_preview_buf(tmpbuf)
    self.win:update_preview_scrollbar()
  end

  fzf_lua.fzf_exec(host_names, vim.tbl_deep_extend("force", {
    prompt = "Remote Host> ",
    previewer = HostPreviewer,
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then
          return
        end
        local name = selected[1]:match "^%s*(.-)%s*$"
        local host = hosts[name]
        if host then
          connections.connect(host)
        end
      end,
    },
  }, opts or {}))
end

--- Picker: edit SSH config file
function M.edit(opts)
  local fzf_lua = require "fzf-lua"
  local connections = require "remote-sshfs.connections"
  local ssh_configs = connections.list_ssh_configs()

  fzf_lua.fzf_exec(ssh_configs, vim.tbl_deep_extend("force", {
    prompt = "SSH Config> ",
    preview = "bat --style=default --color=always -- {}",
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then
          return
        end
        vim.cmd("edit " .. vim.fn.fnameescape(selected[1]))
      end,
    },
  }, opts or {}))
end

--- Picker: remote find_files
function M.find_files(opts)
  local fzf_lua = require "fzf-lua"
  local connections = require "remote-sshfs.connections"

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

  find_command = vim.deepcopy(find_command)

  -- Apply additional options
  local command = find_command[3]
  if opts.hidden and (command == "fd" or command == "fdfind" or command == "rg") then
    find_command[#find_command + 1] = "--hidden"
  end
  if opts.no_ignore and (command == "fd" or command == "fdfind" or command == "rg") then
    find_command[#find_command + 1] = "--no-ignore"
  end
  if opts.follow and (command == "fd" or command == "fdfind" or command == "rg") then
    find_command[#find_command + 1] = "-L"
  end
  if opts.search_dirs then
    vim.list_extend(find_command, opts.search_dirs)
  end

  local cmd_str = table.concat(find_command, " ")

  fzf_lua.fzf_exec(cmd_str, vim.tbl_deep_extend("force", {
    prompt = "Remote Files> ",
    previewer = "builtin",
    fn_transform = function(x)
      if x:sub(1, 2) == "./" then
        x = x:sub(3)
      end
      return x
    end,
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then
          return
        end
        local filename = selected[1]
        if filename:sub(1, 2) == "./" then
          filename = filename:sub(3)
        end
        vim.cmd("edit " .. vim.fn.fnameescape(mount_point .. filename))
      end,
    },
  }, opts or {}))
end

--- Picker: remote live_grep
function M.live_grep(opts)
  local fzf_lua = require "fzf-lua"
  local connections = require "remote-sshfs.connections"

  if not connections.is_connected() then
    vim.notify "You are not currently connected to a remote host."
    return
  end

  opts = opts or {}
  local current_host = connections.get_current_host()
  local mount_point = opts.mount_point or connections.get_current_mount_point()
  local search_dirs = opts.search_dirs

  -- Build base grep command parts
  local base_parts = {
    "ssh",
    current_host["Name"],
    "-C",
    "rg",
    "--color=always",
    "--no-heading",
    "--with-filename",
    "--line-number",
    "--column",
    "--smart-case",
  }

  if opts.type_filter then
    base_parts[#base_parts + 1] = "--type=" .. opts.type_filter
  end
  if type(opts.glob_pattern) == "string" then
    base_parts[#base_parts + 1] = "--glob=" .. opts.glob_pattern
  elseif type(opts.glob_pattern) == "table" then
    for _, glob in ipairs(opts.glob_pattern) do
      base_parts[#base_parts + 1] = "--glob=" .. glob
    end
  end

  local base_cmd = table.concat(base_parts, " ")

  local suffix = " ."
  if search_dirs then
    suffix = " " .. table.concat(search_dirs, " ")
  end

  fzf_lua.fzf_live(function(query)
    if not query or query == "" then
      return "true"
    end
    return base_cmd .. " -- " .. vim.fn.shellescape(query) .. suffix
  end, vim.tbl_deep_extend("force", {
    prompt = "Remote Grep> ",
    previewer = "builtin",
    exec_empty_query = false,
    fn_transform = function(x)
      if x:sub(1, 2) == "./" then
        x = x:sub(3)
      end
      return x
    end,
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then
          return
        end
        local line = fzf_lua.utils.strip_ansi_coloring(selected[1])
        local filename, lnum, col = line:match "^(.+):(%d+):(%d+):"
        if not filename then
          return
        end
        if filename:sub(1, 2) == "./" then
          filename = filename:sub(3)
        end
        vim.cmd("edit " .. vim.fn.fnameescape(mount_point .. filename))
        pcall(vim.api.nvim_win_set_cursor, 0, { tonumber(lnum), tonumber(col) - 1 })
        vim.cmd "normal! zz"
      end,
    },
  }, opts or {}))
end

return M
