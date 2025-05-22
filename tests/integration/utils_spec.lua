local Path = require('plenary.path')
local utils = require('remote-sshfs.utils')
local assert = require('luassert')

describe('remote-sshfs.utils', function()
  describe('parse_host_from_command', function()
    it('parses user, host, path, port', function()
      local cmd = 'user@host:/path -p 2222'
      local h = utils.parse_host_from_command(cmd)
      assert.are.equal('host', h['Name'])
      assert.are.equal('user', h['User'])
      assert.are.equal('/path', h['Path'])
      assert.are.equal('2222', h['Port'])
    end)

    it('parses host:path without user', function()
      local cmd = 'host:/path'
      local h = utils.parse_host_from_command(cmd)
      assert.are.equal('host', h['Name'])
      assert.is_nil(h['User'])
      assert.are.equal('/path', h['Path'])
      assert.is_nil(h['Port'])
    end)

    it('parses host without path', function()
      local cmd = 'host'
      local h = utils.parse_host_from_command(cmd)
      assert.are.equal('host', h['Name'])
      assert.is_nil(h['User'])
      assert.is_nil(h['Path'])
      assert.is_nil(h['Port'])
    end)

    it('parses user@host without path or port', function()
      local cmd = 'user@host'
      local h = utils.parse_host_from_command(cmd)
      assert.are.equal('host', h['Name'])
      assert.are.equal('user', h['User'])
      assert.is_nil(h['Path'])
      assert.is_nil(h['Port'])
    end)

    it('parses host with port only', function()
      local cmd = 'host -p 2222'
      local h = utils.parse_host_from_command(cmd)
      assert.are.equal('host', h['Name'])
      assert.is_nil(h['User'])
      assert.is_nil(h['Path'])
      assert.are.equal('2222', h['Port'])
    end)
  end)

  describe('parse_hosts_from_configs', function()
    local tmpfile

    before_each(function()
      local lines = {
        '# test config',
        'Host a b',
        '  HostName host.example.com',
        '  User tony',
        'Host single',
      }
      tmpfile = Path:new(vim.loop.os_tmpdir(), 'ssh_config_test')
      tmpfile:write(table.concat(lines, '\n'))
    end)

    after_each(function()
      tmpfile:rm()
    end)

    it('parses hosts and attributes', function()
      local res = utils.parse_hosts_from_configs({ tmpfile.filename })
      -- multi-host entry
      assert.are.equal(tmpfile.filename, res['a']['Config'])
      assert.are.equal('a', res['a']['Name'])
      assert.are.equal('host.example.com', res['a']['HostName'])
      assert.are.equal('tony', res['a']['User'])
      assert.are.equal(tmpfile.filename, res['b']['Config'])
      assert.are.equal('b', res['b']['Name'])
      assert.are.equal('host.example.com', res['b']['HostName'])
      assert.are.equal('tony', res['b']['User'])
      -- single host entry
      assert.are.equal(tmpfile.filename, res['single']['Config'])
      assert.are.equal('single', res['single']['Name'])
    end)
  end)
end)