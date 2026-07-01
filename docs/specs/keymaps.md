---
title: Keymap Reference
created: 2026-05-26
updated: 2026-05-26
status: active
topics:
  - keymaps
---

# Keymap Reference

All custom keymaps defined in this config. This does NOT include LazyVim's built-in keymaps (see [LazyVim keymaps reference](https://www.lazyvim.org/keymaps)) except where this config deletes or overrides them.

Leader key is `<Space>` (LazyVim default).

## Global Keymaps (`lua/config/keymaps.lua`)

### Clipboard and Selection

| Key | Mode | Action |
|-|-|-|
| `<C-c>` | n, v | Yank to system clipboard |
| `<C-a>` | n | Select all (`gg<S-v>G`) |
| `p` | v | Paste without overwriting register (swapped with `P`) |
| `P` | v | Paste overwriting register (swapped with `p`) |

`vim.opt.clipboard = "unnamedplus"` is set, so all yanks go to system clipboard by default.

### Increment / Decrement

| Key | Mode | Action |
|-|-|-|
| `=` | n | Increment number under cursor (remapped from `<C-a>`) |
| `-` | n | Decrement number under cursor (remapped from `<C-x>`) |

### Navigation and Scrolling

| Key | Mode | Action |
|-|-|-|
| `j` / `k` | n | Move by display line (`gj`/`gk`), works on wrapped lines |
| `<C-d>` | n, v | Scroll 20 lines down + center cursor |
| `<C-u>` | n, v | Scroll 20 lines up + center cursor |
| `n` / `N` | n | Next/prev search result + center cursor |

### Windows

| Key | Mode | Action |
|-|-|-|
| `sv` | n | Vertical split |
| `<C-S-h>` | n | Shrink window width by 2 |
| `<C-S-l>` | n | Grow window width by 2 |
| `<C-S-k>` | n | Grow window height by 2 |
| `<C-S-j>` | n | Shrink window height by 2 |

### Buffers

| Key | Mode | Action |
|-|-|-|
| `<leader>o` | n | Open Oil file explorer |
| `<leader>e` | n | Open Oil file explorer (alias) |
| `<leader>ba` | n | Delete all buffers |
| `<leader>bn` | n | Move buffer right (BufferLine) |
| `<leader>bp` | n | Move buffer left (BufferLine) |

### Search and Replace

| Key | Mode | Action |
|-|-|-|
| `<leader>r` | n | grug-far: search/replace in current file |
| `<leader>j` | n | Replace-next pattern: `*``cgn` (select word, change next) |

### Yank Paths

| Key | Mode | Action |
|-|-|-|
| `<leader>yp` | n | Yank file path relative to cwd |
| `<leader>yP` | n | Yank file path relative to home |

### LSP

| Key | Mode | Action |
|-|-|-|
| `<leader>cp` | n | Stop LSP server (`:LspStop`) |

### Disabled Keys

| Key | Mode | Reason |
|-|-|-|
| `q` | n, v | Macro recording disabled |
| `S` | n | Conflicts with mini.surround workflow |
| `<leader>uz` | n | Fold toggle removed |
| `<leader>uZ` | n | Fold toggle removed |
| `<leader>bp` | n | Original LazyVim binding deleted, remapped to BufferLine move |
| `<leader>bP` | n | Original LazyVim binding deleted |

## Plugin Keymaps

### Bufferline (`lua/ui/bufferline.lua`)

| Key | Mode | Action |
|-|-|-|
| `<Tab>` | n | Next buffer |
| `<S-Tab>` | n | Previous buffer |
| `<leader>bs` | n | Sort buffers by relative directory |

### fzf-lua (`lua/search/fzf.lua`)

| Key | Mode | Action |
|-|-|-|
| `<leader>/` | n | Live grep (cwd) |
| `` <leader>` `` | n | Live grep, literal/fixed-strings (cwd) |
| `<leader><space>` | n | Find files (cwd) |

### grug-far (`lua/search/grug-far.lua`)

| Key | Mode | Action |
|-|-|-|
| `<leader>sr` | n, v | Search/replace (filtered to current file extension) |

### Harpoon (`lua/search/harpoon2.lua`)

| Key | Mode | Action |
|-|-|-|
| `<leader>a` | n | Add file to harpoon list |
| `<leader>h` | n | Toggle harpoon quick menu |
| `<leader>1` - `<leader>5` | n | Jump to harpoon file 1-5 |

### Arrow (`lua/search/arrow.lua`)

| Key | Mode | Action |
|-|-|-|
| `;` | n | Open global file bookmarks |
| `m` | n | Open per-buffer bookmarks |

### blink.cmp (`lua/langs/blink.lua`)

| Key | Mode | Action |
|-|-|-|
| `<C-space>` | i | Show completion / toggle docs |
| `<C-k>` | i | Toggle signature help |
| `<C-e>` | i | Hide completion |
| `<C-f>` | i | Accept selected item |
| `<C-p>` / `<C-n>` | i | Previous / next item |
| `<Up>` / `<Down>` | i | Previous / next item |
| `<C-.>` / `<C-,>` | i | Scroll docs up / down |

Explicitly unbound from completion: `<CR>`, `<Tab>`, `<S-Tab>`, `<C-b>`.

### Flash (`lua/misc/flash.lua`)

| Key | Mode | Action |
|-|-|-|
| `s` | n, x, o | Flash jump (LazyVim default, kept) |
| `S` | — | Disabled (would be treesitter search) |

### nvim-spider (`lua/misc/nvim-spider.lua`)

| Key | Mode | Action |
|-|-|-|
| `w` | n, o, x | Subword-aware forward word |
| `b` | n, o, x | Subword-aware backward word |
| `e` | n, o, x | Subword-aware end of word |

### Multicursor (`lua/misc/multicursor.lua`)

| Key | Mode | Action |
|-|-|-|
| `<leader>zn` | n, x | Add cursor at next match |
| `<leader>zs` | n, x | Skip match, move to next |
| `<leader>zN` | n, x | Add cursor at previous match |
| `<leader>zS` | n, x | Skip match, move to previous |
| `<leader>zr` | n | Restore cleared cursors |
| `<C-LeftMouse>` | n | Add cursor at click |
| `<C-LeftDrag>` | n | Drag to add cursors |
| `<C-q>` | n, x | Toggle cursor |
| `<Esc>` | n (layer) | Enable or clear cursors |

### Checkmate (`lua/misc/checkmate.lua`)

All keymaps are markdown-only (`ft = "markdown"`).

| Key | Mode | Action |
|-|-|-|
| `<leader>tt` | n, v | Toggle todo |
| `<leader>tc` | n, v | Check (done) |
| `<leader>tu` | n, v | Uncheck |
| `<leader>t=` | n, v | Cycle next state |
| `<leader>t-` | n, v | Cycle previous state |
| `<leader>tn` | n, v | Create todo |
| `<leader>tr` | n, v | Remove todo marker |
| `<leader>tR` | n, v | Remove all metadata |
| `<leader>ta` | n | Archive completed |
| `<leader>tF` | n | Picker: select todo |
| `<leader>tp` | n | Add `@priority` tag |
| `<leader>ts` | n | Add `@started` tag |
| `<leader>td` | n | Add `@done` tag |
| `<leader>tv` | n | Update metadata value |
| `<leader>t]` / `<leader>t[` | n | Jump next/prev metadata |

### Oil (`lua/ui/oil.lua`)

These keymaps are active only inside Oil buffers.

| Key | Action |
|-|-|
| `<C-s>` | Save buffer (overrides Oil's default split action) |
| `q` | Close Oil |
| `gs` | grug-far: search in current Oil directory |
| `<leader>fo` | Open current directory in macOS Finder |
| `<C-h>` | Disabled (was horizontal split) |
| `<C-t>` | Disabled (was open in new tab) |

### nvim-dap (`dap.core` extra)

Debugger keymaps, prefix `<leader>d`. Enabled by the `dap.core` extra. See `debugging.md` for full usage and per-language setup.

| Key | Mode | Action |
|-|-|-|
| `<leader>db` | n | Toggle breakpoint |
| `<leader>dB` | n | Breakpoint with condition |
| `<leader>dc` | n | Run / Continue |
| `<leader>da` | n | Run with arguments |
| `<leader>dC` | n | Run to cursor |
| `<leader>dg` | n | Go to line (no execute) |
| `<leader>di` | n | Step into |
| `<leader>dO` | n | Step over |
| `<leader>do` | n | Step out |
| `<leader>dj` | n | Down a stack frame |
| `<leader>dk` | n | Up a stack frame |
| `<leader>dl` | n | Run last |
| `<leader>dP` | n | Pause |
| `<leader>dr` | n | Toggle REPL (in Rust buffers: Rust Debuggables) |
| `<leader>ds` | n | Session info |
| `<leader>dt` | n | Terminate |
| `<leader>dw` | n | Widgets (hover value) |
| `<leader>du` | n | Toggle dap-ui |
| `<leader>de` | n, x | Evaluate expression |
