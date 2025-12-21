return {
  "petertriho/nvim-scrollbar",
  event = "VeryLazy",
  dependencies = {
    "lewis6991/gitsigns.nvim", -- Git integration
    "kevinhwang91/nvim-hlslens", -- Enhanced search
  },
  config = function()
    -- Get Catppuccin colors
    -- This loads the active flavor (mocha, macchiato, frappe, or latte)
    local colors = require("catppuccin.palettes").get_palette()

    require("scrollbar").setup({
      show_in_active_only = true,
      hide_if_all_visible = true,
      throttle_ms = 100,

      -- Custom colors that match Catppuccin
      handle = {
        color = colors.surface0, -- Catppuccin's subtle background
        blend = 30,
      },

      -- Styled marks using Catppuccin's color palette
      marks = {
        Search = {
          text = { "-", "=" },
          priority = 1,
          color = colors.peach, -- Catppuccin orange
        },
        Error = {
          text = { "-", "=" },
          priority = 2,
          color = colors.red, -- Catppuccin red
        },
        Warn = {
          text = { "-", "=" },
          priority = 3,
          color = colors.yellow, -- Catppuccin yellow
        },
        Info = {
          text = { "-", "=" },
          priority = 4,
          color = colors.sky, -- Catppuccin blue
        },
        Hint = {
          text = { "-", "=" },
          priority = 5,
          color = colors.teal, -- Catppuccin teal
        },
        Misc = {
          text = { "-", "=" },
          priority = 6,
          color = colors.mauve, -- Catppuccin purple
        },
        GitAdd = {
          text = "│",
          priority = 7,
          gui = nil,
          color = nil,
          cterm = nil,
          color_nr = nil,
          highlight = "GitSignsAdd",
        },
        GitChange = {
          text = "│",
          priority = 7,
          gui = nil,
          color = nil,
          cterm = nil,
          color_nr = nil,
          highlight = "GitSignsChange",
        },
        GitDelete = {
          text = "▁",
          priority = 7,
          gui = nil,
          color = nil,
          cterm = nil,
          color_nr = nil,
          highlight = "GitSignsDelete",
        },
      },

      excluded_filetypes = {
        "prompt",
        "TelescopePrompt",
        "noice",
        "neo-tree",
        "dashboard",
        "alpha",
        "lazy",
        "mason",
        "notify",
        "toggleterm",
        "lazyterm",
      },

      excluded_buftypes = {
        "terminal",
        "nofile",
      },

      handlers = {
        cursor = true,
        diagnostic = true,
        gitsigns = true, -- Requires gitsigns.nvim
        handle = true,
        search = true, -- Requires nvim-hlslens
      },
    })

    -- Setup search integration
    require("scrollbar.handlers.search").setup({
      -- Automatically hide search marks when leaving search
      calm_down = true,
      -- Nearest search result gets a different color
      nearest_only = false,
    })

    -- Setup gitsigns integration
    require("scrollbar.handlers.gitsigns").setup()
  end,
}
