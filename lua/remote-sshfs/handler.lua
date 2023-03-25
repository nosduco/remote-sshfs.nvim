local utils = require "remote-sshfs.utils"

local M = {}

M.sshfs_wrapper = function(data, mount_dir, callback)
  local output = table.concat(data, "\n")
  if output == "" or string.match(output, "read:") then
    return
  end
  if string.match(output, "ssh_askpass") then
    M.askpass_handler(callback)
  elseif string.match(output, "Authenticated") then
    M.authenticated_handler(mount_dir)
  else
    print("Connection failed: " .. string.gsub(tostring(output), "\r\n", ""))
  end
  -- elseif string.match(output, "connection refused") then
  --   M.connection_refused_handler()
  -- elseif string.match(output, "No route to host") then
  --   M.no_route_handler()
  -- elseif string.match(output, "denied") then
  --   M.permission_denied_handler()
  -- end

  -- TODO: Add mount point handler (and other handlers)
end

M.on_exit_handler = function(mount_dir, callback)
  if vim.loop.fs_stat(mount_dir) then
    vim.loop.fs_rmdir(mount_dir, function(err)
      if err then
        print("Error cleaning mount directory (" .. mount_dir .. "): ", err)
      end
    end)
  end
  callback()
end

M.askpass_handler = function(callback)
  callback "ask_pass"
end

M.authenticated_handler = function(mount_dir)
  print "Connected to host succesfully."

  if M.change_dir then
    if M.confirm_change_dir then
      local prompt = "Change current directory to remote server?"
      utils.prompt_yes_no(prompt, function(item_short)
        utils.clear_prompt()
        if item_short == "y" then
          utils.change_directory(mount_dir)
        end
      end)
    else
      utils.change_directory(mount_dir)
    end
  end

  if M.find_files then
    utils.find_files()
  end
end

M.setup = function(opts)
  M.clean_mount_folders = opts.handlers.on_disconnect.clean_mount_folders
  M.change_dir = opts.handlers.on_connect.change_dir
  M.confirm_change_dir = opts.ui.confirm.change_dir
  M.find_files = opts.handlers.on_connect.find_files
end

return M
