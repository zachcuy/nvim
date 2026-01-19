return {
  "folke/snacks.nvim",
  opts = {
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
