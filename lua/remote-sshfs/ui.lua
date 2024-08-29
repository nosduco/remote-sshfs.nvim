local M = {}

M.prompt = function(prompt_input, prompt_select, items_short, items_long, callback)
  local function format_item(short)
    for i, s in ipairs(items_short) do
      if short == s then
        return items_long[i]
      end
    end
  end

  if M.select_prompts then
    vim.ui.select(items_short, { prompt = prompt_select, format_item = format_item }, function(item_short)
      callback(item_short)
    end)
  else
    vim.ui.input({ prompt = prompt_input }, function(item_short)
      callback(item_short)
    end)
  end
end

M.prompt_yes_no = function(prompt_input, callback)
  local result = M.prompt(prompt_input .. " y/n: ", prompt_input, { "y", "n" }, { "Yes", "No" }, callback)
  vim.schedule(function()
    vim.cmd "startinsert"
  end)
  return result
end

M.clear_prompt = function()
  if vim.opt.cmdheight._value ~= 0 then
    vim.cmd "normal! :"
  end
end

M.setup = function(opts)
  M.select_prompts = opts.select_prompts
end

return M
