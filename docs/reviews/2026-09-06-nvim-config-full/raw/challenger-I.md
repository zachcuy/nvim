## H3: DOWNGRADED to MEDIUM
Original: `custom_commentstring = function() return vim.bo.commentstring end` kills treesitter-aware commentstrings (JSX, HTML `<style>`, markdown fences).
Verdict: DOWNGRADED to MEDIUM

### Evidence
`/Users/zcu/.config/nvim/lua/misc/mini-comment.lua:6-10`
```lua
      options = {
        custom_commentstring = function()
          return vim.bo.commentstring
        end,
      },
```
`/Users/zcu/.local/share/nvim/lazy/mini.comment/lua/mini/comment.lua:460-462`
```lua
  local cs
  if vim.is_callable(options.custom_commentstring) then cs = options.custom_commentstring(ref_position) end
  cs = cs or MiniComment.get_commentstring(ref_position)
```
`comment.lua:379-401` is the native walk (`traverse` over `lang_tree:children()`, `vim.filetype.get_option(ft,'commentstring')`, `return ts_cs or buf_cs`) — unreachable when `cs` is non-nil, and `vim.bo.commentstring` is never nil/empty for these filetypes.
`.../nvim-ts-context-commentstring/lua/ts_context_commentstring/config.lua:66,106-109,78,82`: `c = '/* %s */'`; `tsx = { __default = '// %s', ... jsx_element = '{/* %s */}', jsx_fragment = '{/* %s */}' ...}`; `html = '<!-- %s -->'`; `lua = { __default = '-- %s', ...}`; `:132 M.config.languages.javascript = M.config.languages.tsx`.
`internal.lua:121-123`: `if type(language_config) == 'string' then return language_config end` (string short-circuit, before any node walk).
`utils.lua:104-112`: `for_each_tree` picks the deepest tree whose `ltree:lang()` is in `only_languages` — for a plain `.c` buffer that is the root `c` tree, so `check_node` returns `/* %s */` and the extra's `or vim.bo.commentstring` never runs.
Parsers present (so the treesitter path is live, not theoretical): `~/.local/share/nvim/site/parser/{tsx,typescript,javascript,css,html,markdown,lua,c,cpp,angular}.so`. `/Users/zcu/.config/nvim/lazyvim.json:3,10,13,14` — mini-comment, markdown, tailwind, typescript extras enabled.

### Reasoning
The override wins over the extra (user's `misc` import is later — `lua/config/lazy.lua:28` vs the auto-imported extra) and returns a non-nil string on every call, so BOTH ts-context and mini.comment's own injection walk are dead. `gcc` in JSX markup gives `// %s` instead of `{/* %s */}`, in `<style>` gives `<!-- %s -->` instead of `/* %s */`, in a ```lua fence gives `<!-- %s -->` instead of `-- %s`. The stated root cause is confirmed exactly: ts-context's hardcoded `c = '/* %s */'` short-circuits as a string, so LazyVim's fallback cannot rescue plain C. Severity drops to MEDIUM because the claimed "silent" property is false — the wrong comment markers appear in the buffer the instant `gcc` runs and `u` reverts them; no data loss, no security impact, no hidden state. Scope is 3-4 filetypes of an editing convenience, not a correctness invariant of the config.

### Fix Assessment
Correct, with one coupling defect. `{ "JoosepAlviste/nvim-ts-context-commentstring", opts = { languages = { c = "// %s" } } }` works: `config.lua:136 M.update` is `vim.tbl_deep_extend('force', M.config, config or {})`, so only `languages.c` is replaced; `enable_autocmd = false` from the extra survives `Util.merge` (util.lua:452-470, key-wise override); `lazy = true` survives because the user fragment omits the key; on first `require("ts_context_commentstring.internal")` lazy.nvim runs `auto_load` → `_load` → `M.config` → `require(main).setup(opts)` (loader.lua:531-543, 361-362, 375-388) with `main` resolving to `ts_context_commentstring` (`normname` collapses both to `tscontextcommentstring`, util.lua:68-71; loader.lua:406-420). Defect: "delete lua/misc/mini-comment.lua" also deletes the `formatoptions` autocmd — H3's fix must not land unless M14's relocation lands in the same change, or comment continuation stripping disappears entirely.

Counter-argument: one could hold HIGH because JSX commented with `//` is rendered as literal text rather than removed, i.e. a functional wrong result, and typescript/markdown are the user's daily filetypes. It still stands as MEDIUM: the wrong markers are on screen immediately and reverting is one keystroke, which is the discriminator this scale uses for HIGH ("silent / must be undone by hand" — neither holds).

## M14: CONFIRMED
Original: mini-comment autocmds are positional `opts` entries created at spec-parse time, no augroup, dead `h`/`hpp` patterns, and `vim.opt` clobbers global `formatoptions`.
Verdict: CONFIRMED (MEDIUM)

### Evidence
`/Users/zcu/.config/nvim/lua/misc/mini-comment.lua:11-23` — both `vim.api.nvim_create_autocmd(...)` calls sit inside the `opts` table constructor as positional entries; the `BufEnter` callback is `vim.opt.formatoptions:remove({ "c", "r", "o" })`.
`lazy.nvim core/plugin.lua:157-159`
```lua
          local mod, err = loadfile(modpath)
          if mod then
            local ret, foo = mod()
```
`plugin.lua:184` `package.loaded[modname] = nil`; `plugin.lua:326,335` `Config.spec = Spec.new()` … `Config.spec:parse(specs)`.
`lazy/manage/reloader.lua:86-88,101` `if not (start or #changes == 0) then M.reload(changes)` … `Plugin.load()`; `lazy/core/config.lua:188-190` `change_detection = { enabled = true` — not disabled in `/Users/zcu/.config/nvim/lua/config/lazy.lua:39-42` (only `checker`).
`util.lua:440-441,459-462` `can_merge` is true for the mixed table (`is_list` false), so `opts[1]`/`opts[2]` reach `require("mini.comment").setup(opts)`; `comment.lua:414-428` type-checks named keys only.
`runtime/lua/vim/filetype.lua:347 hpp = 'cpp'`, `:561 h = detect.header`; `runtime/ftplugin/c.lua:2 vim.bo.commentstring = '// %s'`; `ftplugin/cpp.vim:17 setlocal commentstring=//\ %s`.
`runtime/lua/vim/_options.lua:926 vim.opt = create_option_accessor()` (no scope) → `:690,716` `api.nvim_set_option_value(self._name, value, { scope = scope })` with `scope == nil` = `:set` semantics; `:929 vim.opt_local = create_option_accessor('local')`.

### Reasoning
All four sub-claims verify. (1) The autocmds are created during `require("lazy").setup()` when `loadfile(modpath)()` evaluates the module — `event = "VeryLazy"` and `enabled` cannot gate a table constructor — and their integer ids are silently swallowed by `MiniComment.setup`. (2) `change_detection` is on, and a save to any spec file re-enters `Plugin.load()` → `Spec:parse` → import with `package.loaded` cleared → the module body runs again, adding two more anonymous autocmds each time; unbounded within a session, though each duplicate is idempotent (same `commentstring`, same flag removal), so the cost is per-`BufEnter` work and debuggability, not wrong behavior. (3) `h`/`hpp` never exist as filetypes, and the `c`/`cpp` half duplicates the stock ftplugins — and cannot beat ts-context anyway, since `custom_commentstring` bypasses `vim.bo.commentstring` in LazyVim's variant. (4) is the only behavioral defect: `vim.opt` writes global+local, so every `BufEnter` overwrites the global `formatoptions` with the current buffer's flags minus `c,r,o`; after a `.ts` buffer (ftplugin/typescript.vim:17 `formatoptions-=t formatoptions+=croql`) the global permanently loses `t`. Impact is latent, not observable today: nothing in `/Users/zcu/.config/nvim` sets `textwidth` (grep for `textwidth|tw =` returns zero hits), and `t` only acts when `textwidth > 0`. MEDIUM holds on the aggregate — a global option mutated as a side effect plus an unbounded autocmd leak — not on (4) alone, which by itself would be LOW.

### Fix Assessment
Directionally correct, one regression to close. Deleting the c/cpp autocmd is right (`ftplugin/c.lua:2`, `cpp.vim:17` already do it; C is handled by H3's `languages.c`). The relocated autocmd is correct on the two points that are verifiable: `vim.opt_local` writes local only (`_options.lua:929`), and the `FileType` listener necessarily runs after the ftplugin's `setlocal`, because `filetype.vim`/`ftplugin.vim` register the `filetypeplugin` augroup at startup step 6 while user config is step 7 (`doc/starting.txt:456-463`) and Nvim appends autocmds in definition order (`doc/autocmd.txt:49-50`) — strictly more robust than BufEnter-only regardless of the BufEnter/FileType order for fresh loads, which the docs do not specify (do not assert it). Regression: today's autocmd is created inside `require("lazy").setup()` (startup), whereas `lua/config/autocmds.lua` loads at `VeryLazy` when `nvim` is started with no file arguments (`LazyVim/lua/lazyvim/config/init.lua:179-191`, `lazy_autocmds = vim.fn.argc(-1) == 0`); the initial `[No Name]` buffer fires neither event afterwards and would keep `jcroqlnt`. The runtime fact `formatoptions == "jtqnl"` in that buffer shows today's version does catch it. Add, immediately after registering the autocmd, a one-shot `vim.opt_local.formatoptions:remove({ "c", "r", "o" })` for the current buffer — that makes the load-timing question moot. Also drop the `"jtqnl"`-vs-`"jqlnt"` reordering explanation: the flag set matches, the order difference is cosmetic and its mechanism was not read.

Counter-argument: one could dismiss (1)-(3) as style — the autocmds do work, duplicates are idempotent, dead patterns are inert — leaving only a latent `t` loss and arguing LOW. It still stands as MEDIUM: `change_detection` guarantees the duplicate set grows with every config save in a session, and a global option silently rewritten from an unrelated plugin's `opts` table is the kind of defect that surfaces as an unreproducible "my `gq`/auto-wrap stopped working" months later.
