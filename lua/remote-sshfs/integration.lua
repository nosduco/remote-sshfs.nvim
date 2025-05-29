-- Shared helper functions used by various optional UI integrations
-- (statusline, file browser columns, etc.).  Keeping them here avoids code
-- duplication between individual adapters like *statusline.lua* or
-- *filebrowser/oil.lua*.

local M = {}

-------------------------------------------------------------------------------
-- Icon -----------------------------------------------------------------------
-------------------------------------------------------------------------------

M.icon = vim.g.remote_sshfs_status_icon or "󰀻" -- nf-mdi-server (similar to VSCode)

-------------------------------------------------------------------------------
-- Host info ------------------------------------------------------------------
-------------------------------------------------------------------------------

-- Returns current host table or nil
local function current_host()
  local ok, conn = pcall(require, "remote-sshfs.connections")
  if not ok or type(conn) ~= "table" then
    return nil
  end
  if not conn.is_connected or not conn.is_connected() then
    return nil
  end
  if not conn.get_current_host then
    return nil
  end
  return conn.get_current_host()
end

-- Public helper: Returns nil when not connected, else "󰀻 hostname"
function M.label()
  local host = current_host()
  if not host then
    return nil
  end

  local name = host.Name or host.Host or host.HostName or host.host or "remote"
  return string.format("%s %s", M.icon, name)
end

return M
