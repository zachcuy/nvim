return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        astro = { "prettierd", "prettier" },
        c = { "clangd" },
        cpp = { "clangd" },
        html = { "prettierd", "prettier" },
        java = { "prettierd", "prettier" },
        javascript = { "prettierd", "prettier" },
        lua = { "stylua" },
        typescript = { "prettierd", "prettier" },
        rust = { "rust-analyzer" },
        markdown = { "prettierd", "prettier" },
        css = { "prettierd", "prettier" },
      },
    },
  },
}
