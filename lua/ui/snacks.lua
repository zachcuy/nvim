return {
  "folke/snacks.nvim",
  opts = {
    -- Lazygit theme is managed in ~/Library/Application Support/lazygit/config.yml
    -- (includes os.editPreset = "nvim-remote" and Lume theme colors)
    lazygit = {
      configure = false,
      win = {
        style = "lazygit",
        wo = { winhighlight = "NormalFloat:Normal" },
      },
    },
    dashboard = { enabled = false },
    picker = {
      sources = {
        recent = {
          -- Force sorting by the last time the file was accessed
          sort = { fields = { "idx" } },
        },
      },
    },
  },
}
