local connections = require "remote-sshfs.connections"

local M = {}

--- Resolve the picker backend to use.
--- Returns "telescope" or "snacks".
local function resolve_picker()
  local config = require("remote-sshfs").config
  local picker = config and config.ui and config.ui.picker
  if picker then
    return picker
  end

  -- Auto-detect: prefer snacks if available, fall back to telescope
  if pcall(require, "snacks") then
    return "snacks"
  elseif pcall(require, "telescope") then
    return "telescope"
  end

  return "telescope"
end

--- Route a picker action to the configured backend.
--- @param action string One of "connect", "edit", "find_files", "live_grep"
--- @param opts table|nil Options forwarded to the picker
local function picker_action(action, opts)
  local backend = resolve_picker()

  if backend == "snacks" then
    local snacks_pickers = require "remote-sshfs.pickers.snacks"
    snacks_pickers[action](opts)
  else
    local telescope_map = {
      connect = "connect",
      edit = "edit",
      find_files = "find_files",
      live_grep = "live_grep",
    }
    require("telescope").extensions["remote-sshfs"][telescope_map[action]](opts)
  end
end

-- Allow connection to be called via api
M.connect = function(opts)
  picker_action("connect", opts)
end

-- Allow disconnection to be called via api
M.disconnect = function()
  connections.unmount_host()
end

-- Allow config edit to be called via api
M.edit = function(opts)
  picker_action("edit", opts)
end

-- Allow configuration reload to be called via api
M.reload = function()
  connections.reload()
end

-- Trigger remote find_files
M.find_files = function(opts)
  picker_action("find_files", opts)
end

-- Trigger remote live_grep
M.live_grep = function(opts)
  picker_action("live_grep", opts)
end

return M
