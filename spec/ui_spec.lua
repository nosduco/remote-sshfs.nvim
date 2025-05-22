package.path = "lua/?.lua;lua/?/init.lua;" .. package.path
_G.vim = {}
local ui = require "remote-sshfs.ui"

describe("remote-sshfs.ui", function()
  local orig_vim

  before_each(function()
    orig_vim = _G.vim
    _G.vim = {
      ui = {},
      schedule = function(fn) fn() end,
      cmd = function(cmd) _G.vim._cmd = cmd end,
      api = { nvim_replace_termcodes = function(str) return str end, nvim_feedkeys = function(keys, mode) _G.vim._feed = {keys, mode} end },
      opt = { cmdheight = { _value = 1 } },
    }
    _G.vim.ui.select = function(items, opts, cb) cb("selected") end
    _G.vim.ui.input = function(opts, cb) cb("inputted") end
  end)

  after_each(function()
    _G.vim = orig_vim
  end)

  it("prompt uses vim.ui.select when select_prompts is true", function()
    ui.setup({ ui = { select_prompts = true } })
    local result
    ui.prompt("prompt?", "select?", { "a", "b" }, { "A", "B" }, function(choice) result = choice end)
    assert.are.equal("selected", result)
  end)

  it("prompt uses vim.ui.input when select_prompts is false", function()
    ui.setup({ ui = { select_prompts = false } })
    local result
    ui.prompt("prompt?", "select?", { "a", "b" }, { "A", "B" }, function(choice) result = choice end)
    assert.are.equal("inputted", result)
  end)

  it("prompt_yes_no calls prompt and schedules startinsert", function()
    ui.setup({ ui = { select_prompts = false } })
    local result
    ui.prompt_yes_no("prompt", function(choice) result = choice end)
    assert.are.equal("inputted", result)
    assert.is.truthy(vim._cmd:match("startinsert"))
  end)

  it("clear_prompt sends <C-c> when cmdheight non-zero", function()
    ui.clear_prompt()
    assert.are.equal("<C-c>", vim._feed[1])
    assert.are.equal("n", vim._feed[2])
  end)
end)