package.path = "lua/?.lua;lua/?/init.lua;" .. package.path
local utils = require "remote-sshfs.utils"

describe("remote-sshfs.utils.parse_host_from_command", function()
  it("parses user, host, path, port", function()
    local cmd = "user@host:/path -p 2222"
    local result = utils.parse_host_from_command(cmd)
    assert.are.equal("host", result.Name)
    assert.are.equal("user", result.User)
    assert.are.equal("/path", result.Path)
    assert.are.equal("2222", result.Port)
  end)

  it("parses host:path without user", function()
    local cmd = "host:/path"
    local result = utils.parse_host_from_command(cmd)
    assert.are.equal("host", result.Name)
    assert.is_nil(result.User)
    assert.are.equal("/path", result.Path)
    assert.is_nil(result.Port)
  end)

  it("parses host without path", function()
    local cmd = "host"
    local result = utils.parse_host_from_command(cmd)
    assert.are.equal("host", result.Name)
    assert.is_nil(result.User)
    assert.is_nil(result.Path)
    assert.is_nil(result.Port)
  end)

  it("parses user@host without path or port", function()
    local cmd = "user@host"
    local result = utils.parse_host_from_command(cmd)
    assert.are.equal("host", result.Name)
    assert.are.equal("user", result.User)
    assert.is_nil(result.Path)
    assert.is_nil(result.Port)
  end)

  it("parses host with port only", function()
    local cmd = "host -p 2222"
    local result = utils.parse_host_from_command(cmd)
    assert.are.equal("host", result.Name)
    assert.is_nil(result.User)
    assert.is_nil(result.Path)
    assert.are.equal("2222", result.Port)
  end)
end)

