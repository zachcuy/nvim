return {
  "heilgar/bookmarks.nvim",
  dependencies = {
    "kkharji/sqlite.lua",
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("bookmarks").setup({
      default_mappings = false,
      db_path = vim.fn.stdpath("data") .. "/bookmarks.db",
      use_branch_specific = true,
      mappings = {
        add = "ma", -- Add bookmark at current line
        delete = "md", -- Delete bookmark at current line
        list = "ml", -- List all bookmarks
      },
    })
    require("telescope").load_extension("bookmarks")
  end,
  cmd = {
    "BookmarkAdd",
    "BookmarkRemove",
    "Bookmarks",
  },
  keys = {
    { "<leader>ma", "<cmd>BookmarkAdd<cr>", desc = "Add Bookmark" },
    { "<leader>md", "<cmd>BookmarkRemove<cr>", desc = "Remove Bookmark" },
    { "<leader>mj", desc = "Jump to Next Bookmark" },
    { "<leader>mk", desc = "Jump to Previous Bookmark" },
    { "<leader>ml", "<cmd>Bookmarks<cr>", desc = "List Bookmarks" },
    { "<leader>ms", desc = "Switch Bookmark List" },
  },
}
