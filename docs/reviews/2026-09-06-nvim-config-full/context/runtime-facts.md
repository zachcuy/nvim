# Runtime facts (verified 2026-09-06 by the main session; agents cannot run nvim — treat these as ground truth)

## Environment
- Neovim: v0.11.4 (installed via `bob`, binary `~/.local/share/bob/nvim-bin/nvim`; bob also has v0.11.2). Latest stable: v0.12.5 (2026-08-23). 0.11 line latest: v0.11.7 (2026-03-28).
- LazyVim: commit c10948c5, 2026-06-02, "chore(main): release 16.0.0". LazyVim health requires `nvim-0.11.2`.
- lazy.nvim `defaults.lazy = false` (user plugins load eagerly at startup unless they set event/ft/keys/cmd).
- Headless startup to `NVIM STARTED`: 46 ms. Plugins loaded after VeryLazy: 25/59.
- Plugin sources live at `~/.local/share/nvim/lazy/<name>/` — READ THEM to verify option schemas and LazyVim defaults.
- stylua 2.5.2 (Mason: `~/.local/share/nvim/mason/bin/stylua`, NOT on user's PATH). `stylua --check .` reports 5 unformatted files: lua/misc/treesitter-context.lua, lua/search/arrow.lua, lua/config/keymaps.lua, lua/config/autocmds.lua, lua/ui/oil.lua.

## Keymap state after VeryLazy (vim.fn.maparg, normal mode)
- `<leader>bp` = ":BufferLineMovePrev<Return>" (user override WON over LazyVim's Toggle Pin — NOT a bug); `<leader>bP` = nil (deleted); `<leader>bn` = ":BufferLineMoveNext<Return>".
- `<leader>uz` = nil, `<leader>uZ` = nil (deleted). In LazyVim these are `Snacks.toggle.zen()` and `Snacks.toggle.zoom()` (LazyVim lua/lazyvim/config/keymaps.lua:202-203) — NOT fold toggles as the docs claim.
- `n` = "nzz", `N` = "Nzz" (replaces LazyVim's `'Nn'[v:searchforward].'zv'` direction-consistent search, LazyVim keymaps.lua:68-73).
- `s` = Flash jump (LazyVim default) AND `sv` = ":vsplit<Return>" both mapped in normal mode; `timeoutlen` = 300.
- `=` = "<C-a>", `-` = "<C-x>", `S` = "" (disabled), `q` = "" (disabled), `<C-a>` = "gg<S-v>G", `<C-c>` = '"+y', `j` = "gj".
- `<Tab>` = BufferLineCycleNext, `<S-Tab>` = BufferLineCyclePrev; `;` = Arrow file mappings; `m` = Arrow buffer mappings.
- `<leader>ba` = ":bufdo bd<Return>".
- `:LspStop` does not exist until nvim-lspconfig loads (LazyFile event) — expected, not a bug.

## Options after VeryLazy
- clipboard = "unnamedplus" (set in keymaps.lua AND by LazyVim options.lua:57 unless SSH_CONNECTION).
- formatoptions = "jtqnl" (LazyVim sets "jcroqlnt"; mini-comment.lua BufEnter autocmd strips c,r,o globally).
- relativenumber = true, cursorline = false, scrolloff = 3, updatetime = 50, wrap = false, completeopt = "menu,menuone,noselect".
- guicursor set as configured in options.lua:28-39 (line 18 `guicursor = ""` is immediately overwritten). VERIFIED (headless nvim_get_hl after VeryLazy): NormalCursor, InsertCursor, VisualCursor, ReplaceCursor, CommandCursor are ALL EMPTY `{}`; `Cursor` is defined by lume; `lCursor` is a Neovim built-in group (not lume). Cause: lume `load()` runs `hi clear` (lume/lua/lume/init.lua:17-19) because tokyonight set `colors_name` first.
- python3_host_prog = /usr/bin/python3 (exists).

## Plugin load state
- colorscheme = "lume"; tokyonight.nvim LOADED at startup (LazyVim default `colorscheme` opt loads tokyonight in config/init.lua:250-256 before lume overrides it; ~1.1 ms self-time). catppuccin NOT loaded. lume ships `colors/lume.lua`.
- LuaSnip LOADED at startup (~7.8 ms self-time across 62 requires); blink.cmp `snippets.preset` = "default" → blink does NOT use LuaSnip. blink default snippets source scans `stdpath('config')/snippets` and any rtp path matching `friendly.snippets` (blink.cmp lua/blink/cmp/sources/snippets/default/registry.lua:16-17,31-33). CORRECTION (2026-09-06, verified): LazyVim's auto-imported blink extra ALSO declares `rafamadriz/friendly-snippets` as a dependency (LazyVim lua/lazyvim/plugins/extras/coding/blink.lua:25; auto-import wiring at lua/lazyvim/config/init.lua:434). Deleting lua/langs/luasnip.lua therefore does NOT remove friendly-snippets. LazyVim `coding.luasnip` extra is NOT enabled.
- persistence.nvim, markdown-preview.nvim: installed, not loaded at startup (lazy).
- nvim-lspconfig, conform, nvim-lint, mason, fzf-lua, gitsigns, grug-far, mini.surround, nvim-spider, checkmate, render-markdown, dap plugins: lazy (load on LazyFile/keys/ft/cmd).

## External tools (vim.fn.executable, before Mason PATH prepend)
- prettierd=1, prettier=0, clang-format=0, stylua=1 (in nvim after Mason), rustfmt=1, markdownlint-cli2=1, rg=1, fd=1, lazygit=1.
- Mason bin: bash-language-server clangd codelldb js-debug-adapter lua-language-server markdown-toc markdownlint-cli2 marksman ngserver oxfmt php-cs-fixer php-debug-adapter phpactor phpcs shellcheck shfmt stylua tailwindcss-language-server taplo vscode-json-language-server vtsls yaml-language-server. NO clang-format, NO prettier.
- `ngserver` (Angular LS) installed by the angular extra, but lua/langs/lsp.lua sets `angularls = false`.

## LazyVim defaults the user config overrides/duplicates (file:line in ~/.local/share/nvim/lazy/LazyVim/)
- lua/lazyvim/plugins/editor.lua:5-25 grug-far spec — user lua/search/grug-far.lua duplicates it (only diff: `cmd`, and mode {"n","v"} vs {"n","x"}).
- lua/lazyvim/plugins/extras/coding/mini-comment.lua:7-9 sets `custom_commentstring` to `require("ts_context_commentstring.internal").calculate_commentstring() or vim.bo.commentstring`; user lua/misc/mini-comment.lua:7-9 replaces it with plain `vim.bo.commentstring`.
- lua/lazyvim/plugins/ui.lua:5-9 bufferline `event = "VeryLazy"`, keys `<leader>bp` Toggle Pin, `<leader>bP` Delete Non-Pinned.
- lua/lazyvim/plugins/colorscheme.lua tokyonight/catppuccin `lazy = true`; lua/lazyvim/config/init.lua:11-13 default `colorscheme` is a function loading tokyonight; :250-256 applies it at LazyVim setup (priority 10000, before lume at priority 1000).
- lua/lazyvim/config/options.lua: sets number, relativenumber, ignorecase, smartcase, smartindent, expandtab, shiftwidth=2, tabstop=2, termguicolors, undofile, splitright, splitbelow, signcolumn=yes, updatetime=200, scrolloff=4, sessionoptions (incl. "folds"), spelllang, completeopt, cursorline=true, wrap=false, linebreak, formatoptions="jcroqlnt", clipboard (SSH-aware), autoformat=true, snacks_animate=true.
- lua/lazyvim/plugins/extras/lang/angular.lua:30-45 adds `angularls = {}` + a setup hook; :17-22 adds treesitter angular; :27 imports typescript extra.
- lua/lazyvim/plugins/extras/lang/markdown.lua:57 nvim-lint `markdown = { "markdownlint-cli2" }`; :76 markdown-preview.nvim; :96 render-markdown.
- lua/lazyvim/plugins/extras/formatting/prettier.lua (NOT enabled): installs prettier via Mason and wires 16 filetypes with a parser/config condition.
- conform.nvim README.md:138 and :711 — `stop_after_first = true` is required to run only the first available formatter; without it, ALL available formatters in the list run in sequence.
- lua/lazyvim/plugins/extras/lang/clangd.lua does NOT set conform formatters or install clang-format.

## Docs drift already observed (verify independently)
- harpoon documented as active in CLAUDE.md:15, docs/specs/architecture.md:74, docs/specs/plugins.md:106-114, docs/specs/keymaps.md:120-126, KEYMAPS.md:56-64 — but lua/search/harpoon2.lua is fully commented out (commit 941603d "mod: disabled harpoon2").
- CLAUDE.md:52, docs/specs/keymaps.md:91-92 call `<leader>uz`/`<leader>uZ` "Fold toggles" — actually Snacks zen/zoom.
- Oil `gy` keymap (oil.lua:119-132) and checkmate `<leader>tx`/`<leader>th` (checkmate.lua:64-73) absent from docs/specs.
- KEYMAPS.md (root) vs docs/specs/keymaps.md: 362 diff lines; both tracked.
- .neoconf.json tracked but neoconf.nvim is not in lazy-lock.json (not installed).
- 5 dated docs at docs/ root (2026-02-26..2026-03-01) lack frontmatter and are outside docs/investigations/.
- README.md is LazyVim starter boilerplate.
- `ref/` (untracked, empty) and `.tests/` (gitignored, empty) dirs exist at root.
- lazy checkhealth: OK except luarocks/hererocks warnings (no plugin needs luarocks).

## Neovim 0.12 (from release-0.12 runtime/doc/news.txt)
- Breaking: `vim.diff` → `vim.text.diff`; `vim.diagnostic.disable()/is_disabled()` removed; diagnostic signs not via sign_define; `i_CTRL-R` inserts literally; `'shelltemp'` default false; JSON null → vim.NIL in LSP.
- User config greps clean for removed APIs (only `vim.uv or vim.loop` guard in lazy.lua:2, which is fine).
