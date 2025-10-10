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
        rust = { "rustfmt" },
        markdown = { "prettierd", "prettier" },
        css = { "prettierd", "prettier" },
        typescriptreact = { "prettierd", "prettier" }, -- Added TSX support
        javascriptreact = { "prettierd", "prettier" }, -- Added JSX support
        scss = { "prettierd", "prettier" }, -- Added SCSS
        json = { "prettierd", "prettier" }, -- Added JSON
        yaml = { "prettierd", "prettier" }, -- Added YAML
      },
    },
  },
}
