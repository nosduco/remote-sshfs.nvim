local sorters = require "telescope.sorters"
local state = require "telescope.actions.state"
local previewers = require "telescope.previewers"

local function build_host_preview(hosts, name)
  if name == "" or nil then
    return {}
  end

  local lines = {}
  local host = hosts[name]

  table.insert(lines, "Host " .. host["HostName"])
  for key, value in pairs(host) do
    if key ~= "name" then
      table.insert(lines, string.format("\t%s %s", key, value))
    end
  end
  table.insert(lines, "")

  return lines
end

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

  local previewer = previewers.new_buffer_previewer {
    define_preview = function(self, entry)
      local lines = build_host_preview(hosts, entry.value)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      require("telescope.previewers.utils").highlighter(self.state.bufnr, "sshconfig")
    end,
  }

  pickers
    .new(_, {
      prompt_title = "Connect to remote host",
      previewer = previewer,
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
