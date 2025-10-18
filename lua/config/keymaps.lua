local keymap = vim.keymap
local opts = { noremap = true, silent = true }

-- clipboard shit
vim.opt.clipboard = "unnamedplus"
keymap.set({ "n", "v" }, "<C-c>", [["+y]])

-- increment/decrement
keymap.set("n", "=", "<C-a>")
keymap.set("n", "-", "<C-x>")

-- select all
keymap.set("n", "<C-a>", "gg<S-v>G")

-- split window
-- keymap.set("n", "ss", ":split<Return>", opts)
keymap.set("n", "sv", ":vsplit<Return>", opts)

-- resize window
keymap.set("n", "<C-S-h>", "2<C-w><", opts)
keymap.set("n", "<C-S-l>", "2<C-w>>", opts)
keymap.set("n", "<C-S-k>", "2<C-w>+", opts)
keymap.set("n", "<C-S-j>", "2<C-w>-", opts)

-- move up/down work on wrapped lines of text
keymap.set("n", "j", "gj", opts)
keymap.set("n", "k", "gk", opts)

-- re-center cursor after jumps up/down
keymap.set("n", "<C-d>", "20<C-d>zz", opts)
keymap.set("n", "<C-u>", "20<C-u>zz", opts)

-- visual select move down
keymap.set("v", "<C-d>", "20<C-d>zz", opts)
keymap.set("v", "<C-u>", "20<C-u>zz", opts)

-- re-center cursor after search movements up/down
keymap.set("n", "n", "nzz", opts)
keymap.set("n", "N", "Nzz", opts)

-- map p (lower) to P (upper) in visual mode to not stomp on register
keymap.set("v", "p", "P", opts)
keymap.set("v", "P", "p", opts)

-- open oil
keymap.set("n", "<Leader>o", ":Oil<Return>", opts)
keymap.set("n", "<Leader>e", ":Oil<Return>", opts)

-- delete all buffers
keymap.set("n", "<Leader>ba", ":bufdo bd<Return>", { noremap = true, silent = true, desc = "Delete all buffers" })

-- move buffers left/right
keymap.del("n", "<Leader>bp")
keymap.del("n", "<Leader>bP")
keymap.set(
  "n",
  "<Leader>bn",
  ":BufferLineMoveNext<Return>",
  { noremap = true, silent = true, desc = "Move buffer next" }
)
keymap.set(
  "n",
  "<Leader>bp",
  ":BufferLineMovePrev<Return>",
  { noremap = true, silent = true, desc = "Move buffer prev" }
)

-- grug-far (search and replace)
keymap.set(
  "n",
  "<leader>r",
  [[:lua require('grug-far').open({ prefills = { paths = vim.fn.expand("%"), flags = '-F -i' } })<CR>]],
  { noremap = true, silent = true, desc = "Search and Replace Current File" }
)

-- disable the default 's' key behavior (and capital S for consistency)
-- vim.keymap.set({ "n", "x", "o" }, "s", "", { noremap = true })
-- vim.keymap.set({ "n", "x", "o" }, "S", "", { noremap = true })

-- disable default 'S' key since it's equivalent to doing 'cc' and clashes with nvim-surround
vim.keymap.set({ "n" }, "S", "", { noremap = true })

-- disable macro recording
vim.keymap.set({ "n", "v" }, "q", "", { noremap = true })

-- https://vonheikemen.github.io/devlog/tools/how-to-survive-without-multiple-cursors-in-vim/
-- use . to replace the next match
-- use n to skip current match and move onto next
keymap.set("n", "<leader>j", "*``cgn", { noremap = true, silent = true })

-- keymap to disable/pause lsp
keymap.set("n", "<leader>cp", ":LspStop<Return>", { noremap = true, silent = true, desc = "Disable LSP" })

-- custom behavior for dw:
-- dw at the end of the line (after the comma) will delete to the end of that line only
-- dw in the middle of words works as normal
-- vim.keymap.set("n", "dw", function()
--   local cursor_line = vim.fn.line(".")
--   local save_cursor = vim.fn.getcurpos()
--
--   vim.cmd("normal! w")
--   local new_line = vim.fn.line(".")
--
--   vim.fn.setpos(".", save_cursor)
--
--   if new_line ~= cursor_line then
--     vim.cmd("normal! d$")
--   else
--     vim.cmd("normal! dw")
--   end
-- end, { desc = "Delete word (stop at line end)" })

-- custom behavior for cw
-- vim.keymap.set("n", "cw", "ciw", { desc = "Change inner word" })
-- vim.keymap.set("n", "dw", "diw", { desc = "Delete inner word" })
