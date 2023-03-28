local connections = require "remote-sshfs.connections"

local M = {}

-- Allow connection to be called via api
M.connect = function()
  require("telescope").extensions["remote-sshfs"].connect()
end

-- Allow disconnection to be called via api
M.disconnect = function()
  connections.unmount_host()
end

-- Allow config edit to be called via api
M.edit = function()
  require("telescope").extensions["remote-sshfs"].edit()
end

-- Allow configuration reload to be called via api
M.reload = function()
  connections.reload()
end

return M
