local connections = require "remote-sshfs.connections"

local M = {}

M.connect = function()
  vim.cmd "Telescope remote-sshfs connect"
end

M.disconnect = function()
  connections.unmount_host()
end

M.edit = function()
  vim.cmd "Telescope remote-sshfs edit"
end

M.reload = function()
  connections.reload()
end

return M
