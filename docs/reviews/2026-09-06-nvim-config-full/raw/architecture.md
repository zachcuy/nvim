# Architecture Review — nvim config full tree

## HIGH: Cursor highlight groups are defined before the colorscheme wipes them
Location: lua/config/options.lua:21-25
Evidence:
```lua
vim.api.nvim_set_hl(0, "NormalCursor", { fg = "#1e1e2e", bg = "#ffffff" })
vim.api.nvim_set_hl(0, "InsertCursor", { fg = "#1e1e2e", bg = "#ffd400" })
```
Problem: `options.lua` runs during LazyVim init, before any colorscheme; lume then runs `if vim.g.colors_name then vim.cmd("hi clear") end` (lume/lua/lume/init.lua:17-18), and `vim.g.colors_name` is already set because tokyonight loads first (runtime-facts:29,43). lume defines `Cursor`/`CursorIM`/`CursorLine` (lume/lua/lume/groups/editor.lua:22-26) but none of the five `*Cursor` names `guicursor` at options.lua:28-39 refers to.
Impact: The entire cursor-colour feature — a documented core design decision (CLAUDE.md "Cursor: Block cursor in all modes… yellow blinking") — silently resolves to undefined groups, and every future colorscheme swap re-breaks it in the same invisible way.
Fix: Move the five `nvim_set_hl` calls into `lua/ui/colorscheme.lua` after `vim.cmd("colorscheme lume")` (where the `Comment` overrides already live), or register them on a `ColorScheme` autocmd so they survive any re-application. Confirm the current state with `:hi NormalCursor` before/after the change.
Confidence: HIGH
Counter-argument: `hi clear` resets to *defaults* rather than deleting groups, so maybe the groups survive. They cannot — `NormalCursor` has no default definition in Neovim and lume never defines it, so after `hi clear` it is a cleared group. The mechanism is fully traced at lume/init.lua:17-18 and the colours are re-applied nowhere; only the *visible* symptom is unconfirmed, which is why the fix asks for one `:hi` check.

## HIGH: `keymap.del` in keymaps.lua races lazy.nvim's own key handler and can abort the rest of the file
Location: lua/config/keymaps.lua:53-66
Evidence:
```lua
keymap.del("n", "<Leader>bp")
keymap.del("n", "<Leader>bP")
```
Problem: `<leader>bp`/`<leader>bP` are bufferline `keys` entries (LazyVim plugins/ui.lua:5-9). lazy.nvim's keys handler re-creates the real mapping when the plugin loads — `M:_del` does `pcall(vim.keymap.del, ...)` then `self:_set(keys, ...)` → `vim.keymap.set` (lazy/core/handler/keys.lua:185-198). Both bufferline and `config.keymaps` fire on `VeryLazy`, so the user's delete only wins by ordering (runtime-facts:12 confirms it currently does). If either key is ever absent when this line runs, `vim.keymap.del` throws E31, and LazyVim wraps the whole module in one `LazyVim.try(function() require(mod) end, ...)` (LazyVim/lua/lazyvim/config/init.lua:289-291) — so lines 55-109 (buffer moves, `<leader>r`, `S`/`q` disables, `<leader>j`, yank-path maps, `<leader>cp`, the `<leader>uz`/`uZ` deletes) all silently stop being applied.
Impact: A LazyVim upgrade that renames or drops one bufferline key turns into "half my keymaps vanished" with only a notification, and the failure points at the wrong line.
Fix: Delete keymaps.lua:53-66 and express the override where it is owned — in `lua/ui/bufferline.lua`'s `keys` table: `{ "<leader>bp", "<Cmd>BufferLineMovePrev<CR>", desc = "Move buffer prev" }`, `{ "<leader>bn", "<Cmd>BufferLineMoveNext<CR>", desc = "Move buffer next" }`, `{ "<leader>bP", false }`. The `{ lhs, false }` disable form is parsed at lazy/core/handler/keys.lua:35-40 and is already used in-repo at lua/misc/flash.lua:9.
Confidence: HIGH
Counter-argument: "It works today, verified." Correct, and the finding does not claim otherwise — it claims the mechanism is unguarded ordering plus an all-or-nothing failure mode for 55 subsequent lines. The same argument applies to keymaps.lua:108-109, which sit at the end and are therefore harmless; that asymmetry is the point.

## HIGH: mini-comment.lua creates global autocmds as positional entries inside `opts`
Location: lua/misc/mini-comment.lua:11-23
Evidence:
```lua
      vim.api.nvim_create_autocmd("BufEnter", {
        callback = function()
          vim.opt.formatoptions:remove({ "c", "r", "o" })
        end,
        desc = "Disable New Line Comment",
      }),
```
Problem: Three separate boundary violations in one construct. (1) lazy.nvim executes every spec module body at `setup()` time via `loadfile(modpath)` then `mod()` (lazy/core/plugin.lua:157-159), unconditionally — so these autocmds are registered at startup no matter what `event = "VeryLazy"` says, and they would still register if the spec were `enabled = false`. (2) The `BufEnter` handler mutates the global `formatoptions` for every buffer in the editor from a file that owns one comment plugin (runtime-facts:23 shows `formatoptions = "jtqnl"` editor-wide). (3) Both calls return autocmd IDs, which land as `opts[1]`/`opts[2]` and are passed into `MiniComment.setup()`; mini.comment tolerates them (only named fields are validated, mini/comment.lua:410-430) but the opts table no longer means what it reads as. Neither autocmd declares a `group`, so `:Lazy reload mini.comment` stacks duplicates.
Impact: Disabling or removing the mini.comment spec will not remove editor-wide behaviour that appears to belong to it, and the `formatoptions` mutation is unfindable from `autocmds.lua` where a maintainer will look.
Fix: Move both autocmds to `lua/config/autocmds.lua` under a named `vim.api.nvim_create_augroup(..., { clear = true })`, and leave `opts` in mini-comment.lua containing only `options`.
Confidence: HIGH
Counter-argument: "Colocation is deliberate — the C/C++ `commentstring` autocmd genuinely serves mini.comment." True for that one; it still belongs in an augroup and it is still created at parse time rather than plugin-load time. The `BufEnter`/`formatoptions` autocmd has no connection to mini.comment at all, and the positional-entry placement is not colocation, it is a syntax accident.

## MEDIUM: `custom_commentstring` override disables mini.comment's own treesitter resolution and orphans a plugin
Location: lua/misc/mini-comment.lua:7-9
Evidence:
```lua
        custom_commentstring = function()
          return vim.bo.commentstring
        end,
```
Problem: When `custom_commentstring` is unset, mini.comment falls back to `MiniComment.get_commentstring()`, which resolves the commentstring through the active treesitter parser (mini/comment.lua:90 and :359-364). This override replaces both that built-in and the LazyVim extra's ts_context_commentstring integration (LazyVim extras/coding/mini-comment.lua:7-9), and leaves `JoosepAlviste/nvim-ts-context-commentstring` (declared at extras/coding/mini-comment.lua:13-19) installed and never required.
Impact: Embedded-language comments break in exactly the filetypes this config enables extras for — TSX/JSX, HTML/Tailwind, Angular templates, Vue — and the C/C++ `// %s` autocmd at mini-comment.lua:11-17 now exists only to hand-patch one case the removed mechanism handled generically.
Fix: Drop the override and the C/C++ autocmd, and let mini.comment / ts_context_commentstring resolve commentstrings. If buffer-only resolution is genuinely wanted, add a one-line comment saying so and remove `nvim-ts-context-commentstring` from the spec.
Confidence: HIGH
Counter-argument: mini.comment documents this exact snippet (mini/comment.lua:92-99) as the way to "always use buffer 'commentstring' even in case of present active tree-sitter parser", so it is a supported option, not a misuse. It stands because the config pairs it with a manual per-filetype patch — evidence the generic behaviour was wanted after all — and because it silently orphans a plugin the enabled extra installs.

## MEDIUM: Colorscheme selected by side effect instead of LazyVim's option, forcing a second colorscheme to load
Location: lua/ui/colorscheme.lua:6-11
Evidence:
```lua
    config = function()
      require("lume").setup()
      vim.cmd("colorscheme lume")
```
Problem: LazyVim's `colorscheme` option applies tokyonight at setup (config/init.lua:11-13, :250-256, priority 10000) before this spec's priority-1000 `config` overrides it; runtime-facts:29 confirms tokyonight is loaded at startup. The two highlight overrides on lines 9-10 are also applied once imperatively, so any later `:colorscheme` call or `ColorScheme` event drops them.
Impact: Every colorscheme change touches two files with two different mechanisms, and startup carries a whole theme nobody uses.
Fix: Add `{ "LazyVim/LazyVim", opts = { colorscheme = "lume" } }` and reduce this spec to `{ "danfry1/lume", lazy = false, priority = 1000 }`. `require("lume").setup()` is not required — `M.config = vim.deepcopy(defaults)` at lume/lua/lume/init.lua:10 initialises it. Move lines 9-10 (plus the cursor groups from the first finding) into a `ColorScheme` autocmd.
Confidence: HIGH
Counter-argument: tokyonight costs ~1.1 ms (runtime-facts:29), so the double-load is trivially cheap. Agreed — the finding is about the two-mechanism split and the non-reapplied highlights, not the milliseconds.

## MEDIUM: LuaSnip is hand-wired as an undeclared carrier for friendly-snippets
Location: lua/langs/luasnip.lua:1-11
Evidence:
```lua
  config = function()
    require("luasnip.loaders.from_vscode").lazy_load()
    require("luasnip.loaders.from_vscode").lazy_load({ paths = { "~/.config/nvim/snippets" } })
  end,
```
Problem: blink.cmp's `snippets.preset` is `"default"`, so blink never consults LuaSnip; it finds snippets itself by scanning `stdpath('config')/snippets` and any rtp entry matching `friendly.snippets` (blink.cmp sources/snippets/default/registry.lua:16-17,31-33 — runtime-facts:30). LuaSnip therefore loads eagerly at startup (~7.8 ms, 62 requires) with its only surviving contribution being that it lists `friendly-snippets` as a dependency. Line 9 hardcodes the absolute path blink already scans via `stdpath`.
Impact: Deleting this file to remove an unused snippet engine silently removes the community snippet corpus from completion, and the config breaks if it is ever cloned to a path other than `~/.config/nvim`.
Fix: Either enable `lazyvim.plugins.extras.coding.luasnip` via `:LazyExtras` (which wires blink to LuaSnip properly), or replace this file with `return { "rafamadriz/friendly-snippets" }` and drop LuaSnip.
Confidence: HIGH
Counter-argument: LuaSnip may be wanted for direct `require("luasnip")` use elsewhere. Nothing in the tree requires it, and 7.8 ms of startup plus a hidden dependency edge is a real cost for a plugin whose consumer ignores it.

## MEDIUM: Formatters are declared without the Mason install the config already knows how to write
Location: lua/langs/conform.lua:7-10
Evidence:
```lua
        c = { "clang_format" },
        cpp = { "clang_format" },
        html = { "prettierd", "prettier" },
        java = { "prettier" },
```
Problem: `clang_format` and `prettier` are neither on PATH nor in Mason's installed set (runtime-facts:35-36), and the clangd extra installs neither (runtime-facts:49). The config already contains the correct pattern for this exact problem — `lua/langs/dap.lua:8-10` adds `php-debug-adapter` to `mason.nvim`'s `ensure_installed` precisely because LazyVim references a tool it never installs — but that pattern was not applied to formatters. Additionally, none of the multi-entry lists set `stop_after_first`, so conform runs every *available* formatter in the list rather than the first (conform README.md:138, :711).
Impact: `<leader>cf` on a C++ or Java file does nothing and reports nothing; the declaration/installation split means every new formatter added here repeats the omission.
Fix: Add `{ "mason-org/mason.nvim", opts = { ensure_installed = { "clang-format" } } }` to conform.lua (mirroring dap.lua), drop the unreachable `"prettier"` fallbacks or enable `lazyvim.plugins.extras.formatting.prettier` which installs it, and set `stop_after_first = true` on the multi-entry lists.
Confidence: HIGH
Counter-argument: This reads as a correctness bug, not architecture. The architectural half is the boundary: tool *declaration* lives in `langs/conform.lua` while tool *installation* lives in `langs/dap.lua`, with no rule saying which file owns which — that inconsistency is why the omission happened and will happen again.

## MEDIUM: grug-far has three entry points in three files with three prefill conventions
Location: lua/config/keymaps.lua:69-74, lua/ui/oil.lua:80-100, lua/search/grug-far.lua:5-20
Evidence:
```lua
  [[:lua require('grug-far').open({ prefills = { paths = vim.fn.expand("%"), flags = '-F -i' } })<CR>]],
```
Problem: The same plugin is invoked from the core keymaps file (as a Vimscript string, bypassing the spec entirely), from a file-explorer spec in a different import group, and from its own spec — each with different `prefills`, `transient`/`instanceName` handling, and flags. `lua/search/grug-far.lua` is additionally a near-verbatim copy of LazyVim's own spec (LazyVim plugins/editor.lua:5-25, runtime-facts:40); the only deltas are `cmd = "GrugFar"` and `mode = { "n", "v" }` vs `{ "n", "x" }`.
Impact: Changing a shared convention (say, always passing `-F`) requires finding three call sites in three import groups, and the duplicated spec silently diverges from LazyVim on every upgrade.
Fix: Reduce lua/search/grug-far.lua to the actual delta — `{ "MagicDuck/grug-far.nvim", cmd = "GrugFar" }` — and move the `<leader>r` mapping from keymaps.lua into that spec's `keys` table so all grug-far entry points other than oil's live in one file.
Confidence: HIGH
Counter-argument: oil's `gs` must live in oil's `keymaps` table, so full consolidation is impossible. Agreed — the fix targets the two that can consolidate and the duplicate spec, not oil's.

## MEDIUM: `clipboard` is set from keymaps.lua, discarding LazyVim's SSH-aware default
Location: lua/config/keymaps.lua:5
Evidence:
```lua
vim.opt.clipboard = "unnamedplus"
```
Problem: A vim option is set from the keymaps module, which per CLAUDE.md is owned by `options.lua`. LazyVim sets this same option conditionally on `$SSH_CONNECTION` (config/options.lua:57); this line runs later and unconditionally.
Impact: On any SSH session the config now hands every yank to a clipboard provider that may not exist, and a maintainer editing `options.lua` will not find the setting that actually wins.
Fix: Move the line to `lua/config/options.lua`. If the SSH behaviour is unwanted, keep the unconditional value but say so in a one-line comment.
Confidence: HIGH
Counter-argument: It is next to `<C-c>` for readability. Readability of two coupled lines does not outweigh a silently-overridden environment-aware default living in the wrong module.

## MEDIUM: oil.lua depends on five undocumented oil internals
Location: lua/ui/oil.lua:15-18, 152-164
Evidence:
```lua
          local name = entry[require("oil.constants").FIELD_NAME] or ""
```
Problem: `oil.columns.register`, `oil.constants.FIELD_NAME`/`FIELD_TYPE`, `oil.util.parse_url`, `oil.fs.posix_to_os_path`, and the `OilActionsPost` User event are all used here. None appear in oil's documentation — `OilActionsPost` is fired only at oil.nvim/lua/oil/mutator/init.lua:425 and matches nothing in doc/api.md, doc/oil.txt, doc/recipes.md, README.md, or CHANGELOG.md; neither do the other four symbols.
Impact: An oil update can rename any of these without a changelog entry, and the failure surfaces as a broken column render or a buffer-cleanup autocmd that quietly stops running.
Fix: Wrap the `OilActionsPost` handler body in `pcall` so an internal rename degrades instead of erroring on every file operation, and add a comment naming the oil version these internals were verified against.
Confidence: HIGH
Counter-argument: oil offers no public API for custom columns, so the coupling is unavoidable. Correct — which is why the fix is defensive containment plus a version note, not removal.

## MEDIUM: Angular is enabled and disabled in two different files
Location: lua/langs/lsp.lua:6 vs lazyvim.json:7
Evidence:
```lua
        angularls = false, -- Disable Angular Language Server
```
Problem: `lazyvim.plugins.extras.lang.angular` is enabled in lazyvim.json, so the extra adds the treesitter parser, imports the typescript extra, registers `angularls = {}` with a setup hook (LazyVim extras/lang/angular.lua:17-22, :27, :30-45), and installs `ngserver` via Mason (runtime-facts:37). A second file then turns the server off.
Impact: An installed language server nobody uses, and a maintainer reading `lazyvim.json` gets the opposite answer from a maintainer reading `lsp.lua`.
Fix: Decide one way. If the Angular treesitter parser and the typescript-extra import are the parts actually wanted, keep both files but replace the trailing comment with the reason (`-- keep the extra for treesitter/ts; ngserver is too slow on this machine`). If not, disable the extra with `:LazyExtras` and delete lsp.lua.
Confidence: HIGH
Counter-argument: The extra brings more than the server, so keeping it while disabling `angularls` may be intentional. That is exactly why the fix asks for the intent to be recorded rather than for the code to change — an unexplained contradiction across two files is the problem.

## MEDIUM: options.lua comments state the opposite of the code, and a dead netrw block contradicts the lines above it
Location: lua/config/options.lua:5-6, 18, 41-52, 63-64, 95-96, 101-102
Evidence:
```lua
-- Disable relative line numbers
vim.opt.relativenumber = true
```
Problem: Five comments assert the inverse of the value they document — `relativenumber` ("Disable"/`true`), `expandtab` ("Use actual tabs (not spaces)"/`true`), `cursorline` ("Highlight the current line"/`false`), `scrolloff` ("Keep 8 lines"/`3`), and line 18's `vim.opt.guicursor = ""` ("Disable GUI cursor shaping") is dead, overwritten ten lines later at :28-39. Lines 45-52 configure netrw browse/banner/winsize after lines 42-43 disable netrw entirely.
Impact: This file is the config's single source of truth for editor behaviour, and it currently teaches the reader the opposite of what runs; the next person to "fix" a contradiction will change the value instead of the comment.
Fix: Correct the five comments to match the values, delete line 18 and the netrw block at :45-52, and drop settings that merely restate LazyVim's defaults (`number`, `nu`, `ignorecase`, `smartindent`, `termguicolors`, `undofile`, `splitright`, `splitbelow`, `signcolumn`, `wrap`, `linebreak`, `spelllang`, `completeopt` — all in LazyVim config/options.lua) so what remains is the actual delta.
Confidence: HIGH
Counter-argument: Comments are style, not architecture. Comment/value contradictions in the file that defines global editor state are a data-flow problem: they make it impossible to tell an intentional override from a stale leftover, which is precisely the judgement the LazyVim-duplication cleanup requires.

## MEDIUM: Three spec files declare no plugins, and the docs still describe one of them as active
Location: lua/search/harpoon2.lua:1-44, lua/ui/scrollbar.lua:1, lua/misc/disabled.lua:2-5
Evidence:
```lua
return {}
```
Problem: `scrollbar.lua` returns `{}`, `harpoon2.lua` returns a list whose single element is an empty table, and `disabled.lua`'s first element is likewise empty. lazy.nvim silently accepts all three: `Spec:normalize` treats an empty table as a list (`Util.is_list` at lazy/core/util.lua:155-163 returns true for `{}`) and iterates zero times, so no "Invalid plugin spec" error is raised (plugin.lua:96-113). `disabled.lua`'s one active entry disables `neo-tree`, which is not in lazy-lock.json and lives only in `extras/editor/neo-tree.lua` — an extra absent from lazyvim.json, so nothing is being disabled.
Impact: The four import groups are the config's structure, and three of their files are now noise that survives greps; worse, CLAUDE.md:15, docs/specs/architecture.md:74, docs/specs/plugins.md:106-114 and docs/specs/keymaps.md:120-126 all document harpoon's `<leader>a`/`<leader>h`/`<leader>1-5` as working keys that do not exist.
Impact of the neo-tree entry specifically: `disabled.lua` reads as the config's disable registry while containing only a no-op, so the next genuine disable has no working example to copy.
Fix: Delete `harpoon2.lua` and `scrollbar.lua` (git history preserves both), remove the harpoon sections from the four docs, and either delete `disabled.lua` or leave a comment recording that neo-tree is absent because its extra is not enabled.
Confidence: HIGH
Counter-argument: Commented-out configs are a legitimate personal-config idiom for "might re-enable". It stands because the cost here is not the dead code but four documentation files promising keymaps that silently do nothing.

## MEDIUM: fzf grep options are built from the plugin's raw defaults instead of the merged opts
Location: lua/search/fzf.lua:56
Evidence:
```lua
    opts.grep.rg_opts = '-g "!.git" -g "!.jj" ' .. require("fzf-lua.config").defaults.grep.rg_opts
```
Problem: The `opts` function receives the fully merged options as its second argument, but this line reaches past that and reads fzf-lua's own module-level default. Anything set on `opts.grep.rg_opts` earlier in the merge chain is discarded rather than extended. LazyVim's fzf extra does not currently set it (verified at LazyVim extras/editor/fzf.lua:158-163, which sets only `grep.actions`), so nothing is lost today.
Impact: The day LazyVim or a future extra sets `grep.rg_opts`, this line drops it with no error and no visible symptom beyond subtly wrong search results.
Fix: `opts.grep.rg_opts = '-g "!.git" -g "!.jj" ' .. (opts.grep.rg_opts or require("fzf-lua.config").defaults.grep.rg_opts)`.
Confidence: HIGH
Counter-argument: The neighbouring in-place mutation of `config.defaults.actions.files` (lines 34-39) is a bigger smell — but LazyVim uses that identical idiom at extras/editor/fzf.lua:52-75, the values are re-derived on reload because `Loader.deactivate` clears both `plugin._.cache` and the plugin's `package.loaded` entries (lazy/core/loader.lua:230-236), so it is not filed. Line 56 is different: it is a one-character contract break with no framework precedent behind it.
