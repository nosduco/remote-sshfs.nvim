local M = {}

M.sshfs_wrapper = function(job_id, data, event)
end

M.setup = function(opts)
  M.clean_mount_folders = opts.handlers.on_disconnect.clean_mount_folders
end

return M
