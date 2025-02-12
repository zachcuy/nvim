return {
  -- buffer line
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    keys = {
      { "<Tab>", "<Cmd>BufferLineCycleNext<CR>", desc = "Next Buffer" },
      { "<S-Tab>", "<Cmd>BufferLineCyclePrev<CR>", desc = "Prev Buffer" },
      { "<leader>bs", "<Cmd>BufferLineSortByRelativeDirectory<CR>", desc = "Sort Buffers" },
    },
    opts = {
      options = {
        -- mode = "tabs",
        show_buffer_close_icons = false,
        show_close_icon = false,
      },
      highlights = {
        buffer_selected = {
          fg = "#FCF596",
        },
      },
    },
  },
}
