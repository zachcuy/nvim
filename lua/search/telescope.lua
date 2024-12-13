return {
  {
    -- https://github.com/nvim-telescope/telescope.nvim
    "nvim-telescope/telescope.nvim",
    dependencies = {
      {
        "nvim-telescope/telescope-live-grep-args.nvim",
        -- https://github.com/nvim-lua/plenary.nvim
        { "nvim-lua/plenary.nvim" },
      },
    },
    opts = {
      defaults = {
        layout_config = { width = 0.9, height = 0.9 },
        sorting_strategy = "ascending",
        winblend = 0,
      },
      path_display = {
        filename_first = {
          reverse_directories = true,
        },
      },
    },
    keys = {
      {
        "<leader>/",
        "<cmd>lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>",
        desc = "Grep (root dir)",
      },
    },
    config = function(_, opts)
      local tele = require("telescope")
      tele.setup(opts)
      tele.load_extension("live_grep_args")
    end,
  },
}
