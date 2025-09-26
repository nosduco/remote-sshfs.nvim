-- remote-sshfs ⇄ oil.nvim integration
--
-- This helper adds visual cues inside Oil buffers when the user browses a
-- directory located on a remote-sshfs mount.
--
-- 1. Column – shows "󰀻 <host>" in the root row
-- 2. Winbar – sets the same label in the local winbar for Oil buffers

local helper = require "remote-sshfs.integration"

local M = {}

-------------------------------------------------------------------------------
-- utils ----------------------------------------------------------------------
-------------------------------------------------------------------------------

local function host_label()
  return helper.label()
end

-------------------------------------------------------------------------------
-- 1. Column ------------------------------------------------------------------
-------------------------------------------------------------------------------

---Create an Oil column module displaying the current host label.
---@param opts table|nil { hl = 'HighlightGroup' }
function M.column(opts)
  opts = opts or {}

  return function()
    local label = host_label()
    if not label then
      return nil
    end

    local hl = opts.hl or "DiagnosticHint"
    return {
      ---@param entry table Oil row entry
      ---@return string, string? text, highlight
      get_text = function(entry)
        if entry.name == "." then
          return label, hl
        end
        return "", nil
      end,
      column_width = #label,
    }
  end
end

-------------------------------------------------------------------------------
-- 2. Winbar ------------------------------------------------------------------
-------------------------------------------------------------------------------

function M.attach_winbar(opts)
  opts = opts or {}

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "oil",
    group = vim.api.nvim_create_augroup("RemoteSSHFSOilWinbar", { clear = true }),
    callback = function()
      local label = host_label()
      if not label then
        vim.opt_local.winbar = nil
        return
      end

      local hl = opts.hl or "DiagnosticHint"
      if hl and vim.fn.hlexists(hl) == 1 then
        label = string.format("%%#%s#%s%%*", hl, label)
      end
      vim.opt_local.winbar = label
    end,
  })
end

return M
