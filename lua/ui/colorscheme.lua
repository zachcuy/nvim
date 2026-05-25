return {
  {
    "danfry1/lume",
    lazy = false,
    priority = 1000,
    config = function()
      require("lume").setup()
      vim.cmd("colorscheme lume")
      vim.api.nvim_set_hl(0, "Comment", { fg = "#75d7b3", italic = true })
      vim.api.nvim_set_hl(0, "@comment", { fg = "#75d7b3", italic = true })
    end,
  },
}
