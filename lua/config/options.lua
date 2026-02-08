-- host stuff
vim.g.python3_host_prog = "/usr/bin/python3"
vim.g.loaded_perl_provider = 0

-- Disable relative line numbers
vim.opt.relativenumber = true

-- Ensure absolute line numbers are enabled
vim.opt.number = true

-- bugged with nvim-cmp (Jun 17, 2024)
vim.o.cursorcolumn = false

-- Consider - as part of keyword
vim.opt.iskeyword:append("-")

-- Disable GUI cursor shaping (e.g., blinking, color changes)
vim.opt.guicursor = ""

-- Define highlight groups for cursor colors
vim.api.nvim_set_hl(0, "NormalCursor", { fg = "#1e1e2e", bg = "#ffffff" })
vim.api.nvim_set_hl(0, "InsertCursor", { fg = "#1e1e2e", bg = "#ffd400" })
vim.api.nvim_set_hl(0, "VisualCursor", { fg = "#1e1e2e", bg = "#ffd400" })
vim.api.nvim_set_hl(0, "ReplaceCursor", { fg = "#1e1e2e", bg = "#ffd400" })
vim.api.nvim_set_hl(0, "CommandCursor", { fg = "#1e1e2e", bg = "#ffd400" })

-- Configure guicursor
vim.opt.guicursor = {
  "n-v-c-sm:block-NormalCursor/lCursor",

  -- Insert mode: blinking block cursor
  "i-ci-ve:block-InsertCursor/lCursor-blinkwait700-blinkon400-blinkoff250",

  -- Replace mode: blinking block cursor
  "r-cr:block-ReplaceCursor/lCursor-blinkwait700-blinkon400-blinkoff250",

  -- Command mode: blinking block cursor
  "o:block-CommandCursor/lCursor-blinkwait700-blinkon400-blinkoff250",
}

-- Disable netrw plugin
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Set netrw browsing split behavior
vim.g.netrw_browse_split = 0

-- Disable the netrw banner
vim.g.netrw_banner = 0

-- Set the netrw window size
vim.g.netrw_winsize = 25

-- Set line numbers
vim.opt.nu = true

-- Set tab width to 4 spaces
vim.opt.tabstop = 4

-- Set soft tab stop to 4 spaces
vim.opt.softtabstop = 4

-- Use actual tabs (not spaces)
vim.opt.expandtab = true

-- Set the width for auto-indent to the same as tabstop
vim.opt.shiftwidth = 0

-- Enable smart indenting
vim.opt.smartindent = true

-- Set options for code completion
vim.opt.completeopt = "menu,menuone,noselect"

-- Disable line wrapping
-- vim.opt.wrap = false

-- Enable line wrapping and changing line/break indent behavior
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true

-- Disable swap file creation
vim.opt.swapfile = false

-- Disable backup file creation
vim.opt.backup = false

-- Enable persistent undo
vim.opt.undofile = true

-- Ignore case in search patterns
vim.opt.ignorecase = true

-- Highlight the current line
vim.opt.cursorline = true

-- Enable 24-bit RGB color in the terminal
vim.opt.termguicolors = true

-- Keep 8 lines visible above/below the cursor
vim.opt.scrolloff = 3

-- Always show the sign column
vim.opt.signcolumn = "yes"

-- Add "@-@" to the list of valid file name characters
vim.opt.isfname:append("@-@")

-- Set the update time for swapping files, writing swap files, etc.
vim.opt.updatetime = 50

-- Automatically read files when changed outside of Vim
vim.opt.autoread = true

-- Highlight column 80 to help keep code within that limit
-- vim.opt.colorcolumn = "120"

-- Set options for session saving
vim.opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp" }

-- Set spell check language to English
vim.opt.spelllang = { "en" }

-- Open new vertical splits to the right of the current window
vim.opt.splitright = true

-- Open new horizontal splits below the current window
vim.opt.splitbelow = true

-- Disable snacks.nvim animation
vim.g.snacks_animate = false

-- Enable diagnostics by default
vim.diagnostic.enable(true)

-- Disable autoformat by default
vim.g.autoformat = false
