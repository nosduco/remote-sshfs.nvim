local M = {}

function M.check()
  local health = vim.health or require('vim.health')
  health.start('remote-sshfs')

  -- Check for sshfs binary
  if vim.fn.executable('sshfs') == 1 then
    health.ok('sshfs executable found')
  else
    health.error("'sshfs' not found. Please install sshfs (e.g. 'brew install sshfs' or 'sudo apt install sshfs').")
  end

  -- Check for unmount capability
  local has_fusermount = vim.fn.executable('fusermount') == 1
  local has_umount = vim.fn.executable('umount') == 1
  if has_fusermount or has_umount then
    health.ok('Unmount tool found: ' .. (has_fusermount and 'fusermount' or 'umount'))
  else
    health.warn('Neither fusermount nor umount found. Unmounting may fail.')
  end
end

return M