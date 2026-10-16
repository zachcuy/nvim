---
title: Neovim config review (2026-09-06 findings re-checked, plus new findings)
created: 2026-10-16
updated: 2026-10-16
status: active
topics:
  - code-review
  - nvim-config
  - lazyvim
  - tmux
---

# Summary

The 2026-09-06 review (`docs/reviews/2026-09-06-nvim-config-full/raw/report.md`) has not been applied. `git diff --stat 5a320bc HEAD` shows only review artifacts, the checkmate `@done` date shift, a two-line doc change, and `lazy-lock.json` updates. Every prior finding re-checked today still holds.

This review adds eight findings the prior one missed. The most important is outside this repo: tmux runs with `extended-keys off`, so inside tmux four resize keymaps never fire and move between windows instead, and the blink doc-scroll keys type a literal `.` or `,`.

No config files were changed.

Environment: Neovim 0.11.4 (bob), LazyVim 16.0.1, tmux 3.8 inside kitty, branch `macbook-reset` at `4f4fda0`.

# Part 1: 2026-09-06 findings, status today

IDs refer to the prior `report.md`. "Runtime" means a headless `nvim` probe run today (method in the session doc).

| ID | Finding | Status | Evidence today |
|-|-|-|-|
| H1 | Custom cursor highlight groups are empty | Open | Runtime: `NormalCursor`, `InsertCursor`, `ReplaceCursor`, `CommandCursor` all `vim.empty_dict()`. lume `init.lua:18` runs `vim.cmd("hi clear")`. |
| M3 | tokyonight loads at startup, then lume replaces it | Open | Runtime: `tokyonight.nvim = loaded`, `colors_name = lume`. LazyVim `config/init.lua:13` default colorscheme function, applied at `:250-255`. |
| M12 | guicursor: `c` is in the white group, `o:` gets the yellow "command" cursor | Open | Runtime `guicursor` value starts `n-v-c-sm:block-NormalCursor/lCursor` and ends `o:block-CommandCursor/...`. |
| H3 | mini.comment `custom_commentstring` disables treesitter-aware comments | Open | Runtime: user override set, `nvim-ts-context-commentstring = not loaded`. LazyVim `extras/coding/mini-comment.lua:7-9` is the version being replaced. |
| M14 | mini-comment autocmds created as positional `opts` entries | Open | Source unchanged, `lua/misc/mini-comment.lua:11-23`. |
| H4 | LuaSnip loads and nothing reads it | Open | Runtime: `LuaSnip = loaded`, `blink.snippets.preset = default`. blink `sources/snippets/default/registry.lua:17` already reads `stdpath('config') .. '/snippets'`. |
| M2 | conform lists run every available formatter (no `stop_after_first`) | Open | `lua/langs/conform.lua:5-22` has no `stop_after_first`. conform `README.md:711`: "Only run the first available formatter in the list. Defaults to false." `prettierd` is at `/opt/homebrew/bin/prettierd`. |
| M2 | `java = { "prettier" }` is dead | Open | Runtime `conform.java = { "prettier" }`. `prettier` is not on PATH or in Mason bin. |
| M8 | Oil `"<Nop>"` on `<C-h>` blocks window navigation inside Oil | Open | `lua/ui/oil.lua:73`. oil `keymap_util.lua:70` sets any truthy rhs: `if rhs then`. |
| M10 | Oil `gs` uses deprecated grug-far functions | Open | `lua/ui/oil.lua:94,96`. grug-far `grug-far.lua:502` (`open_instance`) and `:516` (`update_instance_prefills`) call `vim.deprecate`. |
| M13 | C/C++ insert-mode `*` auto-close map | Open | Source unchanged, `lua/config/autocmds.lua:19-34`. |
| M21 | `<leader>ba` uses `:bufdo bd` | Open | Runtime map `:bufdo bd<Return>`. `windows.txt:846-847`: "{cmd} must not delete buffers or add buffers to the buffer list." |
| M23 | `"v"` maps also hit Select mode (`p`, `q`) | Open | Runtime: `map.s p = P`, `map.s q =` (empty). |
| H2 | `sv` shares the `s` prefix with Flash | Open | `:checkhealth which-key`: "In mode `n`, <s> overlaps with <sv>". `timeoutlen = 300`. |
| H6 | `vim.keymap.del` is an all-or-nothing failure point | Open (works today) | `lua/config/keymaps.lua:53-54,108-109` unchanged. Runtime `<leader>bp` = `:BufferLineMovePrev<Return>`. |
| H7 | Literal grep (`` <leader>` ``) has no `-e` terminator | Open | `lua/search/fzf.lua:16` ends `-g "!.jj"`. fzf-lua `make_entry.lua:171`: "enables "-e" and "--fixed-strings --" in `rg_opts`". The default `rg_opts` at runtime ends `--max-columns=4096 -e`. |
| M4 | `n`/`N` override is normal-mode only | Open | Runtime: `map.n n = nzz`, `map.x n = 'Nn'[v:searchforward]`. |
| M15 | `<Tab>` takes over `<C-i>` | Open, root cause found | See N1. Same tmux setting. |
| H5 | Doc drift | Open | Harpoon still documented: `CLAUDE.md:15`, `docs/specs/keymaps.md:120-126`, `docs/specs/plugins.md:106-114`, `docs/specs/architecture.md:74`. `<leader>uz`/`uZ` documented as "Fold toggles" (`CLAUDE.md:52`); LazyVim `config/keymaps.lua:202-203` binds `<leader>uz` to zen and `<leader>uZ` to zoom. checkmate `config/init.lua:537-538` drops default keys when a user `keys` table exists. |
| M1, M7, M9 | `<leader>r` scope, `<leader>cp` scope, Oil directory-delete cleanup | Open (source unchanged) | Source lines unchanged. Mechanisms not re-checked today. |
| L1, L2, L8, L9 | Dead files, commented code, stylua drift, tracked cruft | Open | `lua/search/harpoon2.lua` and `lua/ui/scrollbar.lua` are still fully commented out. |

# Part 2: New findings

Ranked by impact.

## N1: tmux `extended-keys off` breaks seven keymaps inside tmux (Medium-High)

**Location:** `~/.config/tmux/tmux.conf` (not this repo). Affected maps: `lua/config/keymaps.lua:20-23`, `lua/langs/blink.lua:16-17`, `lua/ui/bufferline.lua:7`.

**Scope:** only when Neovim runs inside tmux. Outside tmux, kitty speaks the CSI u (Control Sequence Introducer, "u" final byte) key protocol and all of these keys work. `~/.config/kitty/kitty.conf:49-52` already sets `no_op` on `kitty_mod+h/j/k/l`, so kitty does not block them.

**Evidence:**
- `tmux show -sv extended-keys` returns `off`. `client_termfeatures` is `bpaste,ccolour,clipboard,cstyle,focus,RGB,sync,title`, with no `extkeys`.
- Isolated tmux server (`-f /dev/null`, same default), keys sent with `send-keys` into a raw-mode pane:

| Key sent | Bytes the pane received |
|-|-|
| `C-S-h` | `08` (same as `C-h`) |
| `C-h` | `08` |
| `Tab` | `09` |
| `C-i` | `09` (same as `Tab`) |
| `C-.` | `2e` (a plain `.`) |
| `C-,` | `2c` (a plain `,`) |

- Same test with `extended-keys on` and `extended-keys-format csi-u`, after the pane sent `CSI > 4 ; 2 m`: `C-S-h` → `ESC[104;6u`, `C-h` → `ESC[104;5u`, `Tab` → `09`, `C-i` → `ESC[105;5u`, `C-.` → `ESC[46;5u`, `C-,` → `ESC[44;5u`. Every key is distinct.
- Neovim sends `CSI > 4 ; 2 m` itself when the terminal does not answer the CSI u query (`runtime/doc/tui.txt:158-170`).

**Impact inside tmux:**
- `<C-S-h>`, `<C-S-j>`, `<C-S-k>`, `<C-S-l>` (window resize) never fire. Neovim gets `<C-h>` to `<C-l>`, which LazyVim maps to window navigation (`config/keymaps.lua:14-17`). Pressing "resize" moves you to another window.
- blink `<C-.>`/`<C-,>` (scroll docs): Neovim gets a plain `.` or `,` and types it into the buffer. This is derived from the bytes above, not observed in a live session.
- `<Tab>` and `<C-i>` are the same key, so bufferline's `<Tab>` also takes `<C-i>` (jump forward in the jumplist). This is the root cause of prior M15.

**Fix (proposed, not applied), in `tmux.conf`:**
```tmux
set -s extended-keys on
set -s extended-keys-format csi-u
set -as terminal-features 'xterm-kitty:extkeys'
```
The third line tells tmux that kitty supports extended keys, so tmux requests them from kitty (`man tmux`: "tmux will always request extended keys itself if the terminal supports them. See also the extkeys feature"). Use `on`, not `always`. With `on`, only programs that request the new encoding get it.

**Needs a live check:** the kitty-to-tmux leg cannot be tested with `send-keys`. After reloading tmux, open Neovim, enter insert mode, and press `<C-v>` then `Ctrl+Shift+h`. You should see `<C-S-H>`, not `^H`.

## N2: Global `iskeyword+=-` breaks word operations in C, C++, Rust, and TS (Medium)

**Location:** `lua/config/options.lua:14-15`
```lua
-- Consider - as part of keyword
vim.opt.iskeyword:append("-")
```

**Evidence (runtime, C buffer):** `ft = c`, `iskeyword(local) = @,48-57,_,192-255,-`. On the line `  int x = ptr->field-1;`, `<cword>` at `ptr` is `ptr-`, and at `field` it is `field-1`.

**Impact:** anything built on the keyword under the cursor sees `-` as part of the word:
- `*` and `#` search for `\<ptr-\>`, so they miss `ptr;` and `ptr)`.
- `ciw`, `diw`, and `yiw` on `field` take `field-1`.
- `<leader>j` (`` *``cgn ``, `keymaps.lua:89`) inherits the `*` behavior.
- This hits `a-b`, `x-1`, and `p->q` in every C-family, Rust, and TS buffer.

CSS already adds `-` locally (`ftplugin/css.vim:21`, `setlocal iskeyword+=-`). SCSS does not. `scss.vim:10` loads `sass.vim`, but the guard at `sass.vim:19` is `if &filetype =~# '\<s[ac]ss]\>'`, and the stray `]` means it never matches. A `nvim --clean` test confirms this: scss `iskeyword` is `@,48-57,_,192-255`, css is `@,48-57,_,192-255,-`. So the global line adds value in scss, html, tsx, jsx, and yaml (for example, Tailwind class names). In tsx and jsx it also breaks code.

**Fix (proposed):** add `-` only in the filetypes you want, with a FileType autocmd that calls `vim.opt_local.iskeyword:append("-")`. Which filetypes is your decision (see the questions).

## N3: `j`/`k` override drops LazyVim's count handling (Low-Medium)

**Location:** `lua/config/keymaps.lua:26-27`
```lua
keymap.set("n", "j", "gj", opts)
keymap.set("n", "k", "gk", opts)
```
LazyVim already has the count-aware version (`config/keymaps.lua:8`):
```lua
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
```

**Impact:** relative numbers are on (`options.lua:6`). In a wrapped buffer, `5j` moves 5 screen lines, so you land on the wrong line. Wrap is on in gitcommit, plaintex, and typst (LazyVim `config/autocmds.lua:104-107`; your `autocmds.lua:10-17` turns wrap off only for markdown and text), and in any buffer where you toggle `<leader>uw`. Visual mode still uses LazyVim's version, so the two modes behave differently.

**Fix:** delete `keymaps.lua:25-27`. LazyVim's mapping does everything the override does.

## N4: Markdown formatters are still configured; the docs say they are off (Low)

**Location:** `lua/langs/conform.lua:15` (the commented line); `docs/specs/plugins.md:53` says "Markdown formatting is commented out (disabled)."

**Evidence:** runtime `conform.markdown = { "prettier", "markdownlint-cli2", "markdown-toc" }`. It comes from LazyVim's markdown extra (`extras/lang/markdown.lua:36`). A commented-out line does not remove a key that another spec sets.

**Actual effect is narrow** (from `extras/lang/markdown.lua:17-33`):
- `markdownlint-cli2` runs only when the buffer has markdownlint diagnostics. Your `nvim-lint.lua:6` (`markdown = {}`) removes that linter, so it never runs.
- `markdown-toc` runs only on files that contain `<!-- toc -->`.
- `prettier` runs only when conform can find it. It is not on PATH or in Mason, so this means a project's `node_modules`.

Mason still installs `markdownlint-cli2` and `markdown-toc` (`extras/lang/markdown.lua:44`). Both are in `~/.local/share/nvim/mason/bin`.

**Fix (if you want markdown formatting fully off):** set `markdown = {}` and `["markdown.mdx"] = {}` in `formatters_by_ft`. An empty table replaces a list when lazy.nvim merges `opts`. The runtime `lint.markdown = {}` shows this already works for nvim-lint.

## N5: fzf `no_ignore` searches gitignored trees on every keystroke (Low-Medium, tradeoff)

**Location:** `lua/search/fzf.lua:51-61` (commit `cd512b0`, deliberate).

**Evidence:** runtime `fzf.grep.no_ignore = true`, `fzf.grep.hidden = true`, `fzf.files.no_ignore = true`. `rg --help`: "When set, ignore files such as .gitignore, .ignore and .rgignore will not be respected."

**Impact:**
- Performance: live grep runs `rg` again on each query change. With `--no-ignore` that includes `node_modules/`, `target/`, `dist/`, and build output.
- `--no-ignore` also ignores `.ignore` and `.rgignore`, so a single project cannot opt out.
- Security: gitignored secrets (`.env`, credential files) show up in results and in the preview. The risk is local only.

**Options:** (A) go back to the defaults and use the `ctrl-o` toggle you already mapped (`fzf.lua:35,46`) when you need ignored files; (B) keep `no_ignore` and add `-g "!node_modules" -g "!target"` next to the `.git`/`.jj` globs at `fzf.lua:56`. B costs one more line to keep up to date.

## N6: `;` repeat is lost, `,` still repeats (Low)

**Evidence:**
- arrow owns `;` in normal mode (runtime `verbose nmap ;` points at `arrow.nvim/lua/arrow/ui.lua:410`).
- flash skips `;` and `,` in all modes when a normal-mode map already exists (`flash.nvim/lua/flash/plugins/char.lua:109-115`). Arrow loads first, so flash skips `;` but maps `,` (`verbose nmap ,` points at `char.lua:118`).
- In visual and operator-pending mode, `;` falls back to Vim's built-in repeat. flash never calls `setcharsearch` (no match in `flash.nvim/lua/`), so that built-in `;` repeats an old Vim `f`/`t`, or nothing.

**Workaround that already works:** press `f` or `F` again to go to the next or previous match (flash `config.lua:194-204`, clever-f style). Change nothing unless the visual-mode `;` behavior bothers you.

## N7: Python 3 and Node providers are set up but do not work (Low)

**Location:** `lua/config/options.lua:2`.

**Evidence (`:checkhealth vim.provider`):**
- Python: `'/usr/bin/python3' -c '... import neovim ...'` fails. The system Python has no pynvim.
- Node: "Missing "neovim" npm (or yarn, pnpm) package."

**Fix:** replace line 2 with `vim.g.loaded_python3_provider = 0` and add `vim.g.loaded_node_provider = 0`. That clears the health errors and skips provider lookup. No installed plugin has an `rplugin/` directory, and no plugin's `lua/`, `plugin/`, or `autoload/` mentions `has('python3')`, `has('node')`, or a host-prog variable. markdown-preview starts `node` itself (`autoload/mkdp/rpc.vim:44-46`, `executable('node')`), not through the Node provider, so turning the provider off does not affect it.

## N8: Snacks picker `recent` sort setting is never used (Low)

**Location:** `lua/ui/snacks.lua:14-21`.

**Evidence:** runtime `LazyVim.pick.picker.name = fzf`. `<leader>fr` ("Recent") goes through LazyVim's picker, which is fzf-lua. The Snacks picker is on (`snacks.picker.enabled = true`) only because the Snacks explorer uses it. The `recent` source runs only if you call `Snacks.picker.recent()` yourself.

**Fix:** delete the `picker` block. Also fix the line in `docs/specs/plugins.md` that describes it.

# Performance and security

**Performance:**
- tokyonight loads on every startup and is then replaced (M3).
- LuaSnip loads with nothing reading it (H4; the prior review measured about 7.8 ms, not re-measured today).
- prettierd and prettier both run in JS repos (M2).
- `:bufdo bd` makes each listed buffer current before deleting it (M21). That loads unloaded buffers and fires their autocmds. This is derived from `windows.txt:829-837`, not measured.
- `no_ignore` grep and file search walk ignored trees (N5).
- `updatetime = 50` (deliberate) fires CursorHold four times sooner than LazyVim's 200.

**Security:**
- `no_ignore` shows gitignored secrets in previews (N5).
- `<leader>r` widens to the whole cwd in an unnamed buffer (prior M1). This is a data-integrity risk during replace.
- Oil `<leader>fo` passes an argv list to `jobstart` (`oil.lua:113`), so there is no shell injection.
- No network or remote-execution risk found.

# Open items

| Item | Why it is open | What resolves it |
|-|-|-|
| kitty-to-tmux extended keys (N1) | `send-keys` cannot simulate a physical keypress | One live keypress test after the tmux change |
| Select-mode `p` result (M23) | Mapping verified; the typed result is derived | Expand a snippet with a placeholder and type `p` |
| M1, M7, M9 mechanisms | Not re-read today; source lines unchanged | Re-read the grug-far, lspconfig, and oil code paths cited in `report.md` |
