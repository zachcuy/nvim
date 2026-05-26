-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "text" },
  callback = function()
    vim.opt_local.spell = false
    vim.opt_local.conceallevel = 0
    vim.opt_local.wrap = false
  end
})

-- Auto-close block comments in C/C++: typing /* inserts /* | */
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp" },
  callback = function()
    local close = vim.api.nvim_replace_termcodes("*  */<Left><Left><Left>", true, false, true)
    vim.keymap.set("i", "*", function()
      local col = vim.fn.col(".")
      local line = vim.fn.getline(".")
      if line:sub(col - 1, col - 1) == "/" then
        vim.api.nvim_feedkeys(close, "n", false)
      else
        vim.api.nvim_feedkeys("*", "n", false)
      end
    end, { buffer = true })
  end,
})
