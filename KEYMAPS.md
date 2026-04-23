# Keymaps

Custom keymaps on top of [LazyVim defaults](https://www.lazyvim.org/keymaps).

## General

Source: `lua/config/keymaps.lua`

| Key | Mode | Action |
|-|-|-|
| `<C-c>` | n, v | Yank to system clipboard |
| `=` | n | Increment number |
| `-` | n | Decrement number |
| `<C-a>` | n | Select all |
| `sv` | n | Vertical split |
| `<C-S-h>` / `<C-S-l>` | n | Resize window left/right (by 2) |
| `<C-S-k>` / `<C-S-j>` | n | Resize window up/down (by 2) |
| `j` / `k` | n | Move on display lines (respects wrap) |
| `<C-d>` / `<C-u>` | n, v | Scroll 20 lines + re-center |
| `n` / `N` | n | Next/prev search result + re-center |
| `p` | v | Paste without stomping register (mapped to `P`) |
| `P` | v | Paste with register stomp (mapped to `p`) |
| `<leader>o` | n | Open Oil file explorer |
| `<leader>e` | n | Open Oil file explorer |
| `<leader>ba` | n | Delete all buffers |
| `<leader>bn` | n | Move buffer next in bufferline |
| `<leader>bp` | n | Move buffer prev in bufferline |
| `<leader>r` | n | Grug-far search & replace in current file (fixed-string, case-insensitive) |
| `S` | n | Disabled (avoids nvim-surround clash) |
| `q` | n, v | Disabled (no macro recording) |
| `<leader>yp` | n | Yank path relative to cwd |
| `<leader>yP` | n | Yank path relative to home |
| `<leader>j` | n | `*``cgn` — start replacing word under cursor, repeat with `.` |
| `<leader>cp` | n | Stop LSP |

## Bufferline

Source: `lua/ui/bufferline.lua`

| Key | Mode | Action |
|-|-|-|
| `<Tab>` | n | Next buffer |
| `<S-Tab>` | n | Previous buffer |
| `<leader>bs` | n | Sort buffers by relative directory |

## FZF

Source: `lua/search/fzf.lua`

| Key | Mode | Action |
|-|-|-|
| `<leader>/` | n | Live grep (cwd) |
| `` <leader>` `` | n | Live grep literal/fixed-string (cwd) |
| `<leader><space>` | n | Find files (cwd) |

## Harpoon

Source: `lua/search/harpoon2.lua`

| Key | Mode | Action |
|-|-|-|
| `<leader>a` | n | Add file to harpoon list |
| `<leader>h` | n | Toggle harpoon quick menu |
| `<leader>1` – `<leader>5` | n | Jump to harpoon file 1–5 |

## Arrow

Source: `lua/search/arrow.lua`

| Key | Mode | Action |
|-|-|-|
| `;` | n | Arrow leader key (global bookmarks) |
| `m` | n | Arrow buffer leader key (per-buffer marks) |

## Grug-Far (Search & Replace)

Source: `lua/search/grug-far.lua`

| Key | Mode | Action |
|-|-|-|
| `<leader>sr` | n, v | Search and replace (filtered to current file extension) |

## Flash

Source: `lua/misc/flash.lua`

`S` is disabled (Flash's Treesitter-select binding removed). The default `s` for Flash jump is inherited from LazyVim.

## Multicursor

Source: `lua/misc/multicursor.lua`

| Key | Mode | Action |
|-|-|-|
| `<leader>zn` | n, x | Match and add cursor forward |
| `<leader>zN` | n, x | Match and add cursor backward |
| `<leader>zs` | n, x | Match and skip cursor forward |
| `<leader>zS` | n, x | Match and skip cursor backward |
| `<leader>zr` | n | Restore cleared cursors |
| `<C-LeftMouse>` | n | Add/remove cursor with Ctrl+click |
| `<C-LeftDrag>` | n | Drag to add cursors |
| `<C-q>` | n, x | Toggle cursor enabled/disabled |
| `<Esc>` | n | Enable or clear cursors (only when multiple cursors active) |

## nvim-spider (Word Motions)

Source: `lua/misc/nvim-spider.lua`

| Key | Mode | Action |
|-|-|-|
| `w` | n, o, x | CamelCase-aware word forward |
| `b` | n, o, x | CamelCase-aware word backward |
| `e` | n, o, x | CamelCase-aware end of word |

## Oil (File Explorer)

Source: `lua/ui/oil.lua`

These keymaps only apply inside Oil buffers.

| Key | Action |
|-|-|
| `<C-s>` | Save buffer (replaces default open-in-split) |
| `<C-h>` | Disabled |
| `<C-t>` | Disabled |
| `q` | Close Oil |
| `gs` | Grug-far search & replace in current directory |
| `<leader>fo` | Open current directory in macOS Finder |

## Blink.cmp (Completion)

Source: `lua/langs/blink.lua`

These keymaps only apply when the completion menu is active.

| Key | Action |
|-|-|
| `<C-space>` | Show / toggle documentation |
| `<C-k>` | Show / hide signature help |
| `<C-e>` | Hide completion |
| `<C-f>` | Select and accept |
| `<C-p>` / `<C-n>` | Select prev / next |
| `<Up>` / `<Down>` | Select prev / next |
| `<C-.>` / `<C-,>` | Scroll docs up / down |
| `<CR>` | Fallback (disabled from blink) |
| `<Tab>` / `<S-Tab>` | Fallback (disabled from blink) |
| `<C-b>` | Fallback (disabled from blink) |

## Checkmate (Markdown Todos)

Source: `lua/misc/checkmate.lua`

These keymaps only apply in markdown files.

| Key | Mode | Action |
|-|-|-|
| `<leader>tt` | n, v | Toggle todo |
| `<leader>tc` | n, v | Check (mark done) |
| `<leader>tu` | n, v | Uncheck (mark not done) |
| `<leader>t=` | n, v | Cycle todo state next |
| `<leader>t-` | n, v | Cycle todo state previous |
| `<leader>tn` | n, v | Create todo |
| `<leader>tr` | n, v | Remove todo marker |
| `<leader>tR` | n, v | Remove all metadata |
| `<leader>ta` | n | Archive completed todos |
| `<leader>tF` | n | Pick a todo from buffer |
| `<leader>tv` | n | Update metadata value under cursor |
| `<leader>t]` | n | Jump to next metadata tag |
| `<leader>t[` | n | Jump to previous metadata tag |
| `<leader>tp` | n | Insert @priority metadata |
| `<leader>ts` | n | Insert @started metadata |
| `<leader>td` | n | Insert @done metadata |
