
# 🌐 remote-sshfs.nvim [![Actions status](https://github.com/nosduco/remote-sshfs.nvim/workflows/CI/badge.svg)](https://github.com/nosduco/remote-sshfs.nvim/actions)

🚧 **This plugin is currently being developed and may
break or change frequently!** 🚧

Explore, edit, and develop on a remote machine via SSHFS with Neovim. `remote-sshfs.nvim` allows you to edit files on remote hosts via SSHFS as if they were local.

![Demo](https://github.com/nosduco/remote-sshfs.nvim/blob/main/demo.gif)

*Loosely based on the VSCode extension [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh). (Note: this plugin does not install packages on the remote server, instead it conducts finds, greps, etc over SSH and mounts files via SSHFS)*

## ✨ Features

- 📡 **Seamless remote connection** via SSHFS and a select menu using `:RemoteSSHFSConnect` or keybind
- 💾 **Automatic mount management** to mount/unmount automatically with the lifecycle of Neovim
- ⚡ **Live-grep and find-files remote performance** via running underlying binaries on the server and piping the result via SSH

## ⚡️ Requirements

### Neovim

- Neovim >= 0.7.0 **(latest version recommended)**
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim): live grep, find files, and host selector/editor functionality
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim): lua function library

### Local Machine

- [sshfs](https://github.com/libfuse/sshfs): for mounting the remote filesystem
- Check health: run `:checkhealth remote-sshfs` in Neovim to verify that `sshfs` and unmount tools are installed
- [ssh](https://en.wikipedia.org/wiki/Secure_Shell): for secure shell connections to remote hosts

### Remote Machine

- [ssh](https://en.wikipedia.org/wiki/Secure_Shell): for secure shell connections to remote hosts
- (recommended) [ripgrep](https://github.com/BurntSushi/ripgrep), [fd/fdfind](https://github.com/sharkdp/fd), or `where` command: for remote find files functionality
- (recommended) [ripgrep](https://github.com/BurntSushi/ripgrep): for remote live grep functionality

## 📦 Installation

Install using your favorite package manager

```lua
// Using lazy.nvim
return {
  "nosduco/remote-sshfs.nvim",
  dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
  opts = {
    -- Refer to the configuration section below
    -- or leave empty for defaults
  },
}
```

Load the extension with telescope

```lua
require('telescope').load_extension 'remote-sshfs'
```

*Try the command `:RemoteSSHFSConnect`
  to see if `remote-sshfs.nvim` is installed and configured corrected*

## ⚙️ Configuration

Here is an example setup with the default config. You do not have to supply a configuration, use this as a reference.

```lua
require('remote-sshfs').setup{
  connections = {
    ssh_configs = { -- which ssh configs to parse for hosts list
      vim.fn.expand "$HOME" .. "/.ssh/config",
      "/etc/ssh/ssh_config",
      -- "/path/to/custom/ssh_config"
    },
    -- NOTE: Can define ssh_configs similarly to include all configs in a folder
    -- ssh_configs = vim.split(vim.fn.globpath(vim.fn.expand "$HOME" .. "/.ssh/configs", "*"), "\n")
    sshfs_args = { -- arguments to pass to the sshfs command
      "-o reconnect",
      "-o ConnectTimeout=5",
    },
  },
  mounts = {
    base_dir = vim.fn.expand "$HOME" .. "/.sshfs/", -- base directory for mount points
    unmount_on_exit = true, -- run sshfs as foreground, will unmount on vim exit
  },
  handlers = {
    on_connect = {
      change_dir = true, -- when connected change vim working directory to mount point
    },
    on_disconnect = {
      clean_mount_folders = false, -- remove mount point folder on disconnect/unmount
    },
    on_edit = {}, -- not yet implemented
  },
  ui = {
    select_prompts = false, -- not yet implemented
    confirm = {
      connect = true, -- prompt y/n when host is selected to connect to
      change_dir = false, -- prompt y/n to change working directory on connection (only applicable if handlers.on_connect.change_dir is enabled)
    },
  },
  log = {
    enabled = false, -- enable logging
    truncate = false, -- truncate logs
    types = { -- enabled log types
      all = false,
      util = false,
      handler = false,
      sshfs = false,
    },
  },
}
```

## 🚀 Usage

### Commands

**`:RemoteSSHFSConnect`**: Use this command to open the host picker and connect to a remote host (parsed from ssh configs)

**`:RemoteSSHFSConnect <[user@]host>:/path -p <port>`**: Use this command to directly connect to a host with optional user, path, and port variables like you would with `scp` or `sshfs`.

- Examples: `:RemoteSSHFSConnect tony@server:/srv -p 1234`, `:RemoteSSHFSConnect server`, `:RemoteSSHFSConnect tony@server`

**`:RemoteSSHFSDisconnect`**: Use this command to disconnect from a connected host

**`:RemoteSSHFSEdit`**: Use this command to open the ssh config picker to open and edit ssh configs

**`:RemoteSSHFSFindFiles`**: Use this command to initiate a telescope find files window which operates completely remotely via SSH and will open buffers referencing to your local mount.

**`:RemoteSSHFSLiveGrep`**: Use this command to initiate a telescope live grep window which operates completely remotely via SSH and will open buffers referencing to your local mount.

### Keybinds

For conveninece, it is recommended to setup keymappings for these commands.

Setup keymappings using Lua:

```lua
local api = require('remote-sshfs.api')
vim.keymap.set('n', '<leader>rc', api.connect, {})
vim.keymap.set('n', '<leader>rd', api.disconnect, {})
vim.keymap.set('n', '<leader>re', api.edit, {})

-- (optional) Override telescope find_files and live_grep to make dynamic based on if connected to host
local builtin = require("telescope.builtin")
local connections = require("remote-sshfs.connections")
vim.keymap.set("n", "<leader>ff", function()
 if connections.is_connected() then
  api.find_files()
 else
  builtin.find_files()
 end
end, {})
vim.keymap.set("n", "<leader>fg", function()
 if connections.is_connected() then
  api.live_grep()
 else
  builtin.live_grep()
 end
end, {})
```

### Use Cases

With this plugin you can:

- Connect and mount a remote host via SSHFS using the `:RemoteSSHFSConnect` command. This command will trigger a picker to appear where you can select hosts that have been parsed from your SSH config files. Upon selecting a host, remote-sshfs will mount the host (by default at `~/.sshfs/<hostname>`) and change the current working directory to that folder. Additionally, by default, once vim closes the mount will be automatically unmounted and cleaned.
- Disconnect from a remote host that you're current connected to using the `:RemoteSSHFSDisconnect` command
- Select a SSH config to edit via a picker by using the `:RemoteSSHFSEdit` command
- Utilize Telescope Find Files functionality completely remote via SSH by using the `:RemoteSSHFSFindFiles` command (<strong>Note: the remote server must have either [ripgrep](https://github.com/BurntSushi/ripgrep), [fd/fdfind](https://github.com/sharkdp/fd), or the where command</strong>)
- Utilize Telescope Live Grep functionality completely remote via SSH by using the `:RemoteSSHFSLiveGrep` command (<strong>Note: the remote server must have [ripgrep](https://github.com/BurntSushi/ripgrep) installed</strong>)

To learn more about SSH configs and how to write/style one you can read more [here](https://linuxize.com/post/using-the-ssh-config-file/)

## 🧩 Status-line integrations

`remote-sshfs.nvim` ships a tiny helper module that exposes the current
connection (if any) as a **single, reusable component** – so every status-line
framework can opt-in without additional boiler-plate.

The module returns an **empty string** when no host is mounted which makes it
safe to drop into existing layouts.

<details>
<summary><b>NvChad (built-in statusline)</b></summary>

NvChad exposes its UI configuration through the return table of
`lua/chadrc.lua`.  The snippet below shows a minimal way to **add one custom
module** (named `remote`) without touching the rest of the default layout.

```lua
-- ~/.config/nvim/lua/chadrc.lua

local M = {}

-- 1️⃣  Create a callable module for NvChad’s statusline
local remote_module = require("remote-sshfs.statusline").nvchad_module {
  highlight = "St_gitIcons", -- highlight group (optional)
}

--  Option A: use an *existing* highlight group by name (as above).
--  Option B: provide a colour table and the plugin will create a group for you:
-- local remote_module = require("remote-sshfs.statusline").nvchad_module {
--   highlight = { fg = "#6A9955", bold = true },
-- }

-- 2️⃣  Add it to `modules` *and* reference it in `order`
M.ui = {
  statusline = {
    -- theme / separator_style as you already have…

    -- insert the module name wherever you like
    order = { "mode", "file", "git", "%=", "lsp_msg", "%=", "diagnostics", "remote", "lsp", "cwd", "cursor" },

    modules = {
      remote = remote_module,
    },
  },
}

return M
```

Custom icon:

```lua
-- has to be set *before* `require("remote-sshfs")` is executed
vim.g.remote_sshfs_status_icon = ""  -- VS Code-style lock icon
```

When `RemoteSSHFSConnect` succeeds your status-line reads e.g.

```
󰀻 myserver
```

and vanishes as soon as you disconnect.

</details>

## 🤝 Contributing

If you find a bug or have a suggestion for how to improve remote-sshfs.nvim or additional functionality, please feel free to submit an issue or a pull request. We welcome contributions from the community and are committed to making remote-sshfs.nvim as useful as possible for everyone who uses it.

## 🧪 Testing

This repository provides two test suites:

- **Unit tests** – pure-Lua logic, run via [Busted](https://olivinelabs.com/busted/)
- **Integration tests** – Neovim + [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) harness

### Unit tests

```bash
busted
```

### Integration tests (headless)

These require `plenary.nvim` to be on Neovim’s *runtimepath*.

If you already manage plenary with Lazy.nvim/Packer/etc. you can reuse your full config (see “With full config” further below). Otherwise use the minimal, self-contained snippet:

```bash
# 1) Make plenary.nvim available (only once)
git clone https://github.com/nvim-lua/plenary.nvim \
  "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/pack/vendor/start/plenary.nvim

# 2) Run the tests
nvim --headless -u NONE -i NONE \
  -c 'set rtp+=.' \
  -c 'packadd plenary.nvim' \
  -c 'lua require("plenary.test_harness").test_directory("tests/integration")' \
  -c 'qa!'
```

With your **normal** Neovim config (plenary loaded automatically):

```bash
nvim --headless \
  -c 'lua require("plenary.test_harness").test_directory("tests/integration")' \
  -c 'qa!'
```

Using the full config is quicker if plenary is already managed by your setup, but note that it loads *all* of your plugins and mappings, which may introduce unrelated noise.

## 🐞 Gotchas

- Password handling: When key-based authentication isn't used, you'll be prompted to enter a password/passphrase, which is piped to `sshfs -o password_stdin`. Ensure your SSH server allows password auth or use an SSH agent.
- Default mount directory: By default, mounts go into `~/.sshfs/<host>/`. Override `mounts.base_dir` in your setup if you'd like a different location.
- Key-based authentication: This plugin relies on your local SSH config and agent for auth. Make sure `ssh-agent` is running and your keys are loaded, or configure `IdentityFile` in your SSH config.

## 🌟 Credits

- [folke](https://github.com/folke) for documentation inspiration :)

## 📜 License

remote-sshfs.nvim is released under the MIT license. please see the [LICENSE](https://giuthub.com/nosduco/remote-sshfs.nvim/blob/main/LICENSE) file for details.
