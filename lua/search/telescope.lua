return {
  -- https://github.com/nvim-telescope/telescope.nvim
  "nvim-telescope/telescope.nvim",
  dependencies = {
    -- https://github.com/nvim-lua/plenary.nvim
    { "nvim-lua/plenary.nvim" },
  },
  opts = {
    defaults = {
      layout_config = {
        vertical = {
          width = 0.75,
        },
      },
      path_display = {
        filename_first = {
          reverse_directories = true,
        },
      },
    },
  },
}
