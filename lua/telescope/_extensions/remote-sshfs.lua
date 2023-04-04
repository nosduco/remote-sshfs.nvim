local sorters = require "telescope.sorters"
local state = require "telescope.actions.state"
local previewers = require "telescope.previewers"
local log = require "remote-sshfs.log"
local ns_previewer = vim.api.nvim_create_namespace "telescope.previewers"

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

-- Remote find_files implementation
local function find_files(opts)
  local connections
  if pcall(require, "remote-sshfs") then
    connections = require "remote-sshfs.connections"
  else
    error "Cannot find remote-sshfs"
  end

  -- Check that a connection exists
  if not connections.get_current_mount_point() then
    vim.notify "You are not currently connected to a remote host."
    return
  end

  local pickers, finders, from_entry, conf, make_entry, flatten
  if pcall(require, "telescope") then
    pickers = require "telescope.pickers"
    finders = require "telescope.finders"
    previewers = require "telescope.previewers"
    from_entry = require "telescope.from_entry"
    conf = require("telescope.config").values
    make_entry = require "telescope.make_entry"
    flatten = vim.tbl_flatten
  else
    error "Cannot find telescope!"
  end

  local Path
  if pcall(require, "plenary.path") then
    Path = require "plenary.path"
  else
    error "Cannot find plenary"
  end

  -- Setup
  local find_command = { "ssh", "tux", "-C", "fdfind", "--type", "f", "--color", "never" }
  local mount_point = opts.mount_point or connections.get_current_mount_point()

  -- Core find_files functionality
  local command = find_command[1]
  local hidden = opts.hidden
  local no_ignore = opts.no_ignore
  local no_ignore_parent = opts.no_ignore_parent
  local follow = opts.follow
  local search_dirs = opts.search_dirs
  local search_file = opts.search_file

  if command == "fd" or command == "fdfind" or command == "rg" then
    if hidden then
      find_command[#find_command + 1] = "--hidden"
    end
    if no_ignore then
      find_command[#find_command + 1] = "--no-ignore"
    end
    if no_ignore_parent then
      find_command[#find_command + 1] = "--no-ignore-parent"
    end
    if follow then
      find_command[#find_command + 1] = "-L"
    end
    if search_file then
      if command == "rg" then
        find_command[#find_command + 1] = "-g"
        find_command[#find_command + 1] = "*" .. search_file .. "*"
      else
        find_command[#find_command + 1] = search_file
      end
    end
    if search_dirs then
      if command ~= "rg" and not search_file then
        find_command[#find_command + 1] = "."
      end
      vim.list_extend(find_command, search_dirs)
    end
  elseif command == "find" then
    if not hidden then
      table.insert(find_command, { "-not", "-path", "*/.*" })
      find_command = flatten(find_command)
    end
    if follow then
      table.insert(find_command, 2, "-L")
    end
    if search_file then
      table.insert(find_command, "-name")
      table.insert(find_command, "*" .. search_file .. "*")
    end
    if search_dirs then
      table.remove(find_command, 2)
      for _, v in pairs(search_dirs) do
        table.insert(find_command, 2, v)
      end
    end
    -- TODO: Add error logging here
  end

  if opts.cwd then
    opts.cwd = vim.fn.expand(opts.cwd)
  end

  opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)

  if search_dirs then
    for k, v in pairs(search_dirs) do
      search_dirs[k] = vim.fn.expand(v)
    end
  end
  local cwd = opts.cwd or vim.loop.cwd()
  pickers
    .new(opts, {
      prompt_title = "Find Files",
      finder = finders.new_oneshot_job(find_command, opts),
      previewer = previewers.new_buffer_previewer {
        title = "File Preview",
        dyn_title = function(_, entry)
          return Path:new(from_entry.path(entry, false, false)):normalize(cwd)
        end,

        get_buffer_by_name = function(_, entry)
          return from_entry.path(entry, false)
        end,

        define_preview = function(self, entry, _)
          entry.path = mount_point .. entry.filename
          local p = from_entry.path(entry, true)
          if p == nil or p == "" then
            return
          end
          conf.buffer_previewer_maker(p, self.state.bufnr, {
            bufname = self.state.bufname,
            winid = self.state.winid,
            preview = opts.preview,
          })
        end,
      },
      sorter = conf.file_sorter(opts),
    })
    :find()
end

-- Utility function
local opts_contain_invert = function(args)
  local invert = false
  local files_with_matches = false

  for _, v in ipairs(args) do
    if v == "--invert-match" then
      invert = true
    elseif v == "--files-with-matches" or v == "--files-without-match" then
      files_with_matches = true
    end

    if #v >= 2 and v:sub(1, 1) == "-" and v:sub(2, 2) ~= "-" then
      local non_option = false
      for i = 2, #v do
        local vi = v:sub(i, i)
        if vi == "=" then -- ignore option -g=xxx
          break
        elseif vi == "g" or vi == "f" or vi == "m" or vi == "e" or vi == "r" or vi == "t" or vi == "T" then
          non_option = true
        elseif non_option == false and vi == "v" then
          invert = true
        elseif non_option == false and vi == "l" then
          files_with_matches = true
        end
      end
    end
  end
  return invert, files_with_matches
end

-- Remote live_grep implementation
local function live_grep(opts)
  local connections
  if pcall(require, "remote-sshfs") then
    connections = require "remote-sshfs.connections"
  else
    error "Cannot find remote-sshfs"
  end

  -- Check that a connection exists
  if not connections.get_current_mount_point() then
    vim.notify "You are not currently connected to a remote host."
    return
  end

  local pickers, finders, from_entry, actions, conf, make_entry, flatten
  if pcall(require, "telescope") then
    pickers = require "telescope.pickers"
    finders = require "telescope.finders"
    previewers = require "telescope.previewers"
    actions = require "telescope.actions"
    from_entry = require "telescope.from_entry"
    conf = require("telescope.config").values
    make_entry = require "telescope.make_entry"
    flatten = vim.tbl_flatten
  else
    error "Cannot find telescope!"
  end

  local Path
  if pcall(require, "plenary.path") then
    Path = require "plenary.path"
  else
    error "Cannot find plenary"
  end

  -- Setup
  local mount_point = opts.mount_point or connections.get_current_mount_point()
  local vimgrep_arguments = {
    "ssh",
    "tux",
    "-C",
    "rg",
    "--color=never",
    "--no-heading",
    "--with-filename",
    "--line-number",
    "--column",
    "--smart-case",
  }
  -- TODO: Handle if server does not have RIPGREP

  local search_dirs = opts.search_dirs
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  if search_dirs then
    for i, path in ipairs(search_dirs) do
      search_dirs[i] = vim.fn.expand(path)
    end
  end

  local additional_args = {}
  if opts.additional_args ~= nil then
    if type(opts.additional_args) == "function" then
      additional_args = opts.additional_args(opts)
    elseif type(opts.additional_args) == "table" then
      additional_args = opts.additional_args
    end
  end

  if opts.type_filter then
    additional_args[#additional_args + 1] = "--type=" .. opts.type_filter
  end

  if type(opts.glob_pattern) == "string" then
    additional_args[#additional_args + 1] = "--glob=" .. opts.glob_pattern
  elseif type(opts.glob_pattern) == "table" then
    for i = 1, #opts.glob_pattern do
      additional_args[#additional_args + 1] = "--glob=" .. opts.glob_pattern[i]
    end
  end

  local args = flatten { vimgrep_arguments, additional_args }
  opts.__inverted, opts.__matches = opts_contain_invert(args)

  local live_grepper = finders.new_job(function(prompt)
    if not prompt or prompt == "" then
      return nil
    end

    local search_list = search_dirs
    local flattened = flatten { args, "--", prompt, search_list, "." }
    return flattened
  end, opts.entry_maker or make_entry.gen_from_vimgrep(opts), opts.max_results, opts.cwd)

  local jump_to_line = function(self, bufnr, lnum)
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns_previewer, 0, -1)
    if lnum and lnum > 0 then
      pcall(vim.api.nvim_buf_add_highlight, bufnr, ns_previewer, "TelescopePreviewLine", lnum - 1, 0, -1)
      pcall(vim.api.nvim_win_set_cursor, self.state.winid, { lnum, 0 })
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd "norm! zz"
      end)
    end
  end

  pickers
    .new(opts, {
      prompt_title = "Live Grep",
      finder = live_grepper,
      -- previewer = conf.grep_previewer(opts),
      previewer = previewers.new_buffer_previewer {
        title = "Grep Preview",
        dyn_title = function(_, entry)
          return Path:new(from_entry.path(entry, false, false)):normalize(opts.cwd)
        end,

        get_buffer_by_name = function(_, entry)
          return from_entry.path(entry, false)
        end,

        define_preview = function(self, entry, _)
          entry.path = mount_point .. entry.filename
          log.line(vim.inspect(entry))
          local has_buftype = entry.bufnr and vim.api.nvim_buf_get_option(entry.bufnr, "buftype") ~= "" or false
          local p
          if not has_buftype then
            p = from_entry.path(entry, true)
            if p == nil or p == "" then
              return
            end
          end

          if entry.bufnr and (p == "[No Name]" or has_buftype) then
            local lines = vim.api.nvim_buf_get_lines(entry.bufnr, 0, -1, false)
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
            jump_to_line(self, self.state.bufnr, entry.lnum)
          else
            conf.buffer_previewer_maker(p, self.state.bufnr, {
              bufname = self.state.bufname,
              winid = self.state.winid,
              preview = opts.preview,
              callback = function(bufnr)
                jump_to_line(self, bufnr, entry.lnum)
              end,
            })
          end
        end,
      },
      sorter = sorters.highlighter_only(opts),
      attach_mappings = function(_, map)
        map("i", "<c-space>", actions.to_fuzzy_refine)
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
      edit = function(_)
        edit_config(_)
      end,
      find_files = function(opts)
        find_files(opts)
      end,
      live_grep = function(opts)
        live_grep(opts)
      end,
    },
  }
else
  error "Cannot find telescope!"
end
