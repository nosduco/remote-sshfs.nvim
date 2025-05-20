local M = {
  path = nil,
  types = {},
}

M.raw = function(type, format, ...)
  if not M.enabled(type) then
    return
  end

  local line = string.format(format, ...)
  local file = io.open(M.path, "a")
  if file then
    io.output(file)
    io.write(line)
    io.close(file)
  end
end

M.line = function(type, format, ...)
  if M.enabled(type) then
    M.raw(type, string.format("[%s] [%s] %s\n", os.date "%Y-%m-%d %H:%M:%S", type, (format or "???")), ...)
  end
end

M.enabled = function(type)
  return (M.types[type] or M.types.all) and M.path ~= nil
end

M.setup = function(opts)
  if opts.log.enabled and opts.log.types then
    M.path = string.format("%s/remote-sshfs.log", vim.fn.stdpath("cache"))
    M.types = opts.log.types
    if opts.log.truncate then
      os.remove(M.path)
    end
    vim.notify("remote-sshfs logging to " .. M.path)
  end
end

return M
