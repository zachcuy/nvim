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
                -- Disable java_test and java_debug_adapter
                java_test = { enable = false, version = "0.43.0" },
                java_debug_adapter = { enable = false },
                spring_boot_tools = {
                  enable = true,
                },
              })
            end,
          },
        },
      },
    },
  },
}
