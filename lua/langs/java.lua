return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
    },
  },
  {
    "mfussenegger/nvim-dap",
    config = function() end,
  },
  { "nvim-treesitter/nvim-treesitter", opts = {
    ensure_installed = { "java" },
  } },
  {
    "nvim-java/nvim-java",
    config = false,
    dependencies = {
      {
        "neovim/nvim-lspconfig",
        opts = {
          servers = {
            jdtls = {
              -- your jdtls configuration goes here
            },
          },
          setup = {
            jdtls = function()
              require("java").setup({
                -- your nvim-java configuration goes here
              })
            end,
          },
        },
      },
    },
  },
}
