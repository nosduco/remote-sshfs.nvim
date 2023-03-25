local sorters = require "telescope.sorters"
local state = require "telescope.actions.state"

local function connect(_)
  local pickers, finders, actions
  if pcall(require, "telescope") then
    pickers = require "telescope.pickers"
    finders = require "telescope.finders"
    actions = require "telescope.actions"
  else
    error "Cannot find telescope!"
  end

  local local_connections = require "remote-sshfs.connections"
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

          local_connections.connect(host)
        end)
        return true
      end,
    })
    :find()
end

-- Initialize with telescope
local present, telescope = pcall(require, "telescope")
if present then
  return telescope.register_extension {
    exports = {
      connect = function(_)
        connect(_)
      end,
    },
  }
else
  error "Cannot find telescope!"
end
