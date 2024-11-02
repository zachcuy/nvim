return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        c = { "clangd" },
        cpp = { "clangd" },
        java = { "clangd" },
        astro = { "prettier" },
        typescript = { "prettier", "prettierd" },
        javascript = { "prettier", "prettierd" },
        html = { "prettier", "prettierd" },
      },
    },
  },
}
