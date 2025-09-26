local utils = require "remote-sshfs.utils"
local ui = require "remote-sshfs.ui"
local log = require "remote-sshfs.log"

local M = {}

M.sshfs_wrapper = function(data, host, mount_dir, callback)
  local output = table.concat(data, "\n")
  log.line("sshfs", output)
  if output == "" or string.match(output, "read:") then
    return
  end
  if string.match(output, "ssh_askpass") then
    M.askpass_handler(callback)
  elseif string.match(output, "Authenticated") then
    M.authenticated_handler(host, mount_dir)
  else
    vim.notify("Connection failed: " .. string.gsub(tostring(output), "\r\n", ""))
  end
  -- TODO: Add mount point handler (and other handlers)
end

M.on_exit_handler = function(_, mount_dir, skip_clean, callback)
  if M.clean_mount_folders and not skip_clean then
    log.line("handler", "Cleaning up mount directory " .. mount_dir)
    utils.cleanup_mount_dir(mount_dir, callback)
  else
    callback()
  end
end

M.askpass_handler = function(callback)
  callback "ask_pass"
end

M.authenticated_handler = function(host, mount_dir)
  vim.notify "Connected to host succesfully."

  if M.change_dir then
    log.line("handler", "change_dir is true")
    if M.confirm_change_dir then
      local prompt = "Change current directory to remote server?"
      ui.prompt_yes_no(prompt, function(item_short)
        ui.clear_prompt()
        if item_short == "y" then
          utils.change_directory(mount_dir)
        end
      end)
    else
      log.line("handler", "changing dir to" .. mount_dir)
      utils.change_directory(mount_dir)
      log.line("handler", "changed dir to" .. mount_dir)
      vim.cmd('edit .')
    end
  end

  require("remote-sshfs").callback.on_connect_success:trigger(host, mount_dir)
end

M.setup = function(opts)
  M.clean_mount_folders = opts.handlers.on_disconnect.clean_mount_folders
  M.change_dir = opts.handlers.on_connect.change_dir
  M.confirm_change_dir = opts.ui.confirm.change_dir
end

return M
