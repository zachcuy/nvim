return {
  {
    "echasnovski/mini.comment",
    event = "VeryLazy",
    opts = {
      options = {
        custom_commentstring = function()
          return vim.bo.commentstring
        end,
      },
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "c", "cpp", "h", "hpp" },
        callback = function()
          -- Directly setting for C++ files
          vim.bo.commentstring = "// %s"
        end,
      }),
      vim.api.nvim_create_autocmd("BufEnter", {
        callback = function()
          vim.opt.formatoptions:remove({ "c", "r", "o" })
        end,
        desc = "Disable New Line Comment",
      }),
    },
  },
}
