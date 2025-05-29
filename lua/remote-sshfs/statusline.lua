local M = {}

-- Default icon displayed when a connection is active. Nerd-font compatible.
-- Users can override this by setting `vim.g.remote_sshfs_status_icon` before
-- the plugin is loaded or by changing `M.icon` afterwards.
M.icon = vim.g.remote_sshfs_status_icon or "󰀻" -- nf-mdi-server

-- Return a short human-readable string that represents the current connection
-- state. If no connection is active an empty string is returned so that the
-- statusline stays unchanged.
--
-- Examples:
--   ""                    – when not connected
--   "󰀻 myserver"          – when connected to host *myserver*
function M.status()
  local ok, conn = pcall(require, "remote-sshfs.connections")
  if not ok or type(conn) ~= "table" then
    return ""
  end

  if not conn.is_connected or not conn.is_connected() then
    return ""
  end

  local host_tbl = conn.get_current_host and conn.get_current_host() or nil
  local name = "remote"
  if host_tbl and type(host_tbl) == "table" then
    -- Prefer the explicit entries we create while parsing the ssh-config.
    name = host_tbl.Name or host_tbl.Host or host_tbl.host or name
  end

  return string.format("%s %s", M.icon, name)
end

-------------------------------------------------------------------------------
-- READY-MADE COMPONENTS -------------------------------------------------------
-------------------------------------------------------------------------------

-- NvChad (Heirline) component factory.
--
-- Usage inside `custom/chadrc.lua` (NvChad > v2.*):
--
--   local remote = require("remote-sshfs.statusline").nvchad_component()
--   table.insert(M.active_components, remote) -- wherever you like
--
-- The returned table follows Heirline's component specification used by
-- NvChad, i.e. `provider`, `condition` and `hl` keys.
--
-- `opts` (all optional):
--   highlight (table)  – Highlight table passed as-is to Heirline.
function M.nvchad_component(opts)
  opts = opts or {}

  -- Lazily require within the closures because the statusline component is
  -- evaluated *after* the plugin init code has run.
  return {
    condition = function()
      local ok, conn = pcall(require, "remote-sshfs.connections")
      return ok and conn.is_connected and conn.is_connected()
    end,
    provider = function()
      return M.status()
    end,
    hl = opts.highlight or { fg = "green" },
  }
end

-------------------------------------------------------------------------------
-- NvChad (classic v3 statusline) module helper --------------------------------
-------------------------------------------------------------------------------

-- NvChad’s in-house statusline (documented under `:h nvui.statusline`) expects
-- plain strings or Lua callables in the `modules` table.  This helper returns
-- such a callable, so users can simply do
--
--   M.ui = {
--     statusline = {
--       modules = {
--         remote = require("remote-sshfs.statusline").nvchad_module(),
--       }
--     }
--   }
--
-- `opts.highlight` – optional highlight group name, e.g. "St_gitIcons".
function M.nvchad_module(opts)
  opts = opts or {}
  local hl_begin = opts.highlight and ("%#" .. opts.highlight .. "#") or ""
  local hl_end = opts.highlight and "%*" or ""

  return function()
    local s = M.status()
    if s == "" then
      return ""
    end
    return hl_begin .. s .. hl_end
  end
end

-------------------------------------------------------------------------------
-- Fall-back plain string for easy integration in classic statuslines ---------
-------------------------------------------------------------------------------

-- For simple `statusline` settings ("set statusline=%!v:lua..."), return a Lua
-- callable that expands to the status string. Example:
--   vim.o.statusline = "%!v:lua.require('remote-sshfs.statusline').status()"
function M.vim_statusline()
  return M.status()
end

return M
