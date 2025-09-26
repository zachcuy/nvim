return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        astro = { "prettierd", "prettier" },
        c = { "clang_format" },
        cpp = { "clang_format" },
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
