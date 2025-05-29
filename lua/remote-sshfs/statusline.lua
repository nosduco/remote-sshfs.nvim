local helper = require "remote-sshfs.integration"

local M = {}

-- Expose icon through the same table (backwards-compat).
M.icon = helper.icon

-- Delegated helpers ----------------------------------------------------------

function M.status()
  return helper.label() or ""
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

  -- Determine highlight behaviour.
  -- 1) string  → assume existing highlight group name
  -- 2) table   → dynamically create a group once and use it
  -- 3) nil     → no colour decorations
  local hl_begin, hl_end = "", ""

  if opts.highlight then
    local group_name

    if type(opts.highlight) == "string" then
      group_name = opts.highlight
    elseif type(opts.highlight) == "table" then
      group_name = "RemoteSSHFSStl"
      -- Only define once per session.
      if vim.fn.hlexists(group_name) == 0 then
        vim.api.nvim_set_hl(0, group_name, opts.highlight)
      end
    end

    if group_name then
      hl_begin = "%#" .. group_name .. "#"
      hl_end = "%*"
    end
  end

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
