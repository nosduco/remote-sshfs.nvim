-- local main = require('telescope._extensions.project.main')
-- local utils = require('telescope._extensions.project.utils')
local sorters = require "telescope.sorters"
local state = require "telescope.actions.state"

local function host_selector(_, opts)
  local pickers, finders, actions
  if pcall(require, "telescope") then
    pickers = require "telescope.pickers"
    finders = require "telescope.finders"
    -- previewers = require "telescope.previewers"

    actions = require "telescope.actions"
    -- action_state = require "telescope.actions.state"
    -- utils = require "telescope.utils"
    -- conf = require("telescope.config").values
  else
    error "Cannot find telescope!"
  end

  local local_connections = require "remote-ssh.connections"
  local hosts = local_connections.list_hosts()

  pickers
    .new(_, {
      prompt_title = "Connect to remote host",
      finder = finders.new_table {
        results = vim.tbl_keys(hosts),
      },
      sorter = sorters.get_generic_fuzzy_sorter(),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)

          local selection = state.get_selected_entry()
          local host = hosts[selection[1]]

          print(vim.inspect(host))
        end)
        return true
      end,
    })
    :find()
end

local opts = {}

-- Initialize with telescope
local present, telescope = pcall(require, "telescope")
if present then
  return telescope.register_extension {
    exports = {
      host_selector = function(_)
        host_selector(_, opts)
      end,
    },
  }
else
  error "Cannot find telescope!"
end
