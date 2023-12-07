local connections = require "remote-sshfs.connections"

local M = {}

-- Allow connection to be called via api
M.connect = function(opts)
  require("telescope").extensions["remote-sshfs"].connect(opts)
end

-- Allow disconnection to be called via api
M.disconnect = function()
  connections.unmount_host()
end

-- Allow config edit to be called via api
M.edit = function(opts)
  require("telescope").extensions["remote-sshfs"].edit(opts)
end

-- Allow configuration reload to be called via api
M.reload = function()
  connections.reload()
end

-- Trigger remote find_files
M.find_files = function(opts)
  require("telescope").extensions["remote-sshfs"].find_files(opts)
end

-- Trigger remote live_grep
M.live_grep = function(opts)
  require("telescope").extensions["remote-sshfs"].live_grep(opts)
end

return M
