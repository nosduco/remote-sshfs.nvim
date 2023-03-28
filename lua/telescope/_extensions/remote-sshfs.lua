local sorters = require "telescope.sorters"
local state = require "telescope.actions.state"
local previewers = require "telescope.previewers"

-- Build virtualized host file from parsed hosts from plugin
local function build_host_preview(hosts, name)
  if name == "" or nil then
    return {}
  end

  local lines = {}
  local host = hosts[name]

  table.insert(lines, "# Config: " .. host["Config"])
  table.insert(lines, "Host " .. host["Name"])
  for key, value in pairs(host) do
    if key ~= "Name" and key ~= "Config" then
      table.insert(lines, string.format("\t%s %s", key, value))
    end
  end
  table.insert(lines, "")

  return lines
end

-- Telescope action to select a host to connect to
local function connect(_)
  local pickers, finders, actions
  if pcall(require, "telescope") then
    pickers = require "telescope.pickers"
    finders = require "telescope.finders"
    actions = require "telescope.actions"
  else
    error "Cannot find telescope!"
  end

  local connections = require "remote-sshfs.connections"
  local hosts = connections.list_hosts()

  -- Build preivewer and set highlighting for each to "sshconfig"
  local previewer = previewers.new_buffer_previewer {
    define_preview = function(self, entry)
      local lines = build_host_preview(hosts, entry.value)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      require("telescope.previewers.utils").highlighter(self.state.bufnr, "sshconfig")
    end,
  }

  -- Build picker to run connect function when a host is selected
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

          connections.connect(host)
        end)
        return true
      end,
    })
    :find()
end

-- Telescope action to select ssh config file to edit
local function edit_config(_)
  local pickers, finders
  if pcall(require, "telescope") then
    pickers = require "telescope.pickers"
    finders = require "telescope.finders"
    previewers = require "telescope.previewers"
  else
    error "Cannot find telescope!"
  end

  local connections = require "remote-sshfs.connections"
  local ssh_configs = connections.list_ssh_configs()

  pickers
    .new(_, {
      prompt_title = "Choose SSH config file to edit",
      previewer = previewers.new_buffer_previewer {
        -- Set preview highlights to sshconfig for each file
        define_preview = function(self, entry)
          if entry == nil or entry.value == nil then
            return
          end

          local file_path = entry.value
          local bufnr = self.state.bufnr

          vim.api.nvim_buf_set_option(bufnr, "filetype", "sshconfig")
          require("telescope.previewers.utils").highlighter(bufnr, "sshconfig")

          local lines = vim.fn.readfile(file_path)
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        end,
      },
      finder = finders.new_table {
        results = ssh_configs,
      },
      sorter = sorters.get_generic_fuzzy_sorter(),
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
      edit = function(_)
        edit_config(_)
      end,
    },
  }
else
  error "Cannot find telescope!"
end
