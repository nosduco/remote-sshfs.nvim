package.path = "lua/?.lua;lua/?/init.lua;" .. package.path
_G.vim = {}
local utils = require "remote-sshfs.utils"

describe("remote-sshfs.utils", function()
  describe("setup_sshfs", function()
    local created_path
    local orig_vim

    before_each(function()
      orig_vim = _G.vim
      _G.vim = { loop = {}, notify = function() end }
      _G.vim.loop.fs_stat = function(path) return nil end
      _G.vim.loop.fs_mkdir = function(path, mode) created_path = path; return true end
    end)
    after_each(function()
      _G.vim = orig_vim
    end)

    it("creates mount base dir when not exists", function()
      utils.setup_sshfs({ mounts = { base_dir = "/tmp/sshfs" } })
      assert.are.equal("/tmp/sshfs", created_path)
    end)
  end)

  describe("file_exists", function()
    local orig_vim
    before_each(function()
      orig_vim = _G.vim
      _G.vim = { loop = {} }
    end)
    after_each(function()
      _G.vim = orig_vim
    end)

    it("returns true when fs_stat returns non-nil", function()
      vim.loop.fs_stat = function() return {}, nil end
      assert.is_true(utils.file_exists("somepath"))
    end)

    it("returns false when fs_stat returns nil and error", function()
      vim.loop.fs_stat = function() return nil, 'err' end
      assert.is_false(utils.file_exists("somepath"))
    end)
  end)

  describe("setup_mount_dir", function()
    local created_path, callback_ok
    local orig_vim

    before_each(function()
      orig_vim = _G.vim
      _G.vim = { loop = {}, notify = function() end }
      created_path = nil
      callback_ok = false
      _G.vim.loop.fs_stat = function() return nil, 'err' end
      _G.vim.loop.fs_mkdir = function(path, mode) created_path = path; return true end
    end)
    after_each(function()
      _G.vim = orig_vim
    end)

    it("creates mount dir and calls callback when missing", function()
      utils.setup_mount_dir("/tmp/mount", function() callback_ok = true end)
      assert.are.equal("/tmp/mount", created_path)
      assert.is_true(callback_ok)
    end)

    it("calls callback when dir already exists", function()
      vim.loop.fs_stat = function() return {} end
      utils.setup_mount_dir("/tmp/mount", function() callback_ok = true end)
      assert.is_true(callback_ok)
    end)
  end)

  describe("cleanup_mount_dir", function()
    local removed_path, callback_ok
    local orig_vim

    before_each(function()
      orig_vim = _G.vim
      _G.vim = { loop = {}, notify = function() end }
      removed_path = nil
      callback_ok = false
      _G.vim.loop.fs_rmdir = function(path) removed_path = path; return true end
    end)
    after_each(function()
      _G.vim = orig_vim
    end)

    it("removes mount dir and calls callback when exists", function()
      utils.file_exists = function() return true end
      utils.cleanup_mount_dir("/tmp/mount", function() callback_ok = true end)
      assert.are.equal("/tmp/mount", removed_path)
      assert.is_true(callback_ok)
    end)

    it("calls callback when dir does not exist without removing", function()
      utils.file_exists = function() return false end
      utils.cleanup_mount_dir("/tmp/mount", function() callback_ok = true end)
      assert.is_true(callback_ok)
    end)

    it("does not call callback when removal fails", function()
      utils.file_exists = function() return true end
      vim.loop.fs_rmdir = function() return false end
      utils.cleanup_mount_dir("/tmp/mount", function() callback_ok = true end)
      assert.is_false(callback_ok)
    end)
  end)

  describe("parse_hosts_from_configs", function()
    local tmpfile, orig_vim

    before_each(function()
      orig_vim = _G.vim
      _G.vim = {
        fn = {
          expand = function(x) return x end,
          filereadable = function() return 1 end,
          executable = function() return 0 end,
          systemlist = function() return {} end,
        },
        v = { shell_error = 1 },
      }
      tmpfile = "ssh_config_test"
      local lines = {
        "# test config",
        "Host a b",
        "  HostName host.example.com",
        "  User tony",
        "Host single",
      }
      local f = io.open(tmpfile, "w")
      f:write(table.concat(lines, "\n"))
      f:close()
    end)

    after_each(function()
      _G.vim = orig_vim
      os.remove(tmpfile)
    end)

    it("parses hosts and attributes without ssh overrides", function()
      local res = utils.parse_hosts_from_configs({ tmpfile })
      assert.are.equal(tmpfile, res['a'].Config)
      assert.are.equal('a', res['a'].Name)
      assert.are.equal('host.example.com', res['a'].HostName)
      assert.are.equal('tony', res['a'].User)
      assert.are.equal(tmpfile, res['b'].Config)
      assert.are.equal('b', res['b'].Name)
      assert.are.equal('host.example.com', res['b'].HostName)
      assert.are.equal('tony', res['b'].User)
      assert.are.equal(tmpfile, res['single'].Config)
      assert.are.equal('single', res['single'].Name)
    end)
  end)
end)