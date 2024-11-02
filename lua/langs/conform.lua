return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        astro = { "prettier" },
        c = { "clangd" },
        cpp = { "clangd" },
        html = { "prettier" },
        java = { "clangd" },
        javascript = { "prettier" },
        lua = { "stylua" },
        typescript = { "prettier" },
      },
    },
  },
}
