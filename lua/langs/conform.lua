return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        astro = { "prettier" },
        c = { "clangd" },
        cpp = { "clangd" },
        html = { "prettier", "prettierd" },
        java = { "clangd" },
        javascript = { "prettier", "prettierd" },
        lua = { "stylua" },
        typescript = { "prettier", "prettierd" },
      },
    },
  },
}
