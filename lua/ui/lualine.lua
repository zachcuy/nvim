return {
  "nvim-lualine/lualine.nvim",
  opts = {
    sections = {
      lualine_c = {
        {
          "filetype",
          icon_only = true,
          separator = "",
        },
        {
          "filename",
          path = 3,
          shorting_target = 10,
          symbols = {
            modified = "[+]",
            readonly = "[-]",
            unnamed = "[Root]",
            newfile = "[New]",
          },
          cond = function()
            return vim.fn.empty(vim.fn.expand("%")) == 1 or vim.bo.buftype ~= ""
          end,
        },
      },
    },
  },
}
