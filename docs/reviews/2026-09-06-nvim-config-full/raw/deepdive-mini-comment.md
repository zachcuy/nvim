---
title: Deep-dive review — lua/misc/mini-comment.lua
created: 2026-09-06
updated: 2026-09-06
status: final
topics:
  - mini-comment
  - ts-context-commentstring
  - formatoptions
  - lazy-nvim
---

# Deep-dive: `lua/misc/mini-comment.lua`

**Label rule:** ISSUE = a defect exists in the current file as written. Each answer states whether the proposed fix resolves it. Totals: 4 ISSUE / 2 NO ISSUE.

## Q1 — Does removing the override regress C to block comments?

**Answer: YES. Label: NO ISSUE** (the override's rationale is valid; the fix's `languages.c` neutralizes it) — `internal.lua:74-77`, `config.lua:66`.

`calculate_commentstring` picks the deepest matching tree, then keys `config.languages` by the treesitter language:

```lua
  local language = language_tree:lang()
  local language_config = config.get_languages_config()[language]
  return M.check_node(node, language_config, key)
```
(`internal.lua:74-77`). For a plain C buffer `language_config` is the string `c = '/* %s */'` (`config.lua:66`), and `check_node` returns it before any node walk: `if type(language_config) == 'string' then return language_config end` (`internal.lua:121-123`). Reachable: parser present at `/Users/zcu/.local/share/nvim/site/parser/c.so`, so `utils.lua:89` `is_treesitter_active()` is true.

**Counter-argument:** `/* %s */` is legal C. It still stands as the author's motive — per-line block comments are not what `//`-using code wants, and the file exists to defeat exactly this.

## Q2 — Does the `languages` override merge and does `setup` run?

**Label: NO ISSUE.** Deep merge: `config.lua:136` `M.config = vim.tbl_deep_extend('force', M.config, config or {})` — only key `c` is replaced; `enable_autocmd = false` survives (it is a sibling key in `M.config`, untouched).

lazy.nvim merges the two fragments' `opts` with `Util.merge(ret, values)` (`plugin.lua:480`); the user table is not a list (`util.lua:441` `can_merge` → `is_list` false because of the `languages` key), so a true deep merge happens.

`setup` does run despite `lazy = true`: `lazy/init.lua:83` `table.insert(package.loaders, 3, Loader.loader)`; `loader.lua:564` `M.auto_load(modname, ret.modpath)` → `M._load` → `loader.lua:361-362` `if plugin.config or plugin.opts then M.config(plugin) end` → `loader.lua:387` `require(main).setup(opts)`. `main` resolves to `ts_context_commentstring` (`util.lua:69` `normname` maps both names to `tscontextcommentstring`). This completes *before* the triggering `require("ts_context_commentstring.internal")` returns, so config is applied before the first `calculate_commentstring`. `enable_autocmd=false` also disables the CursorHold hook (`internal.lua:19,26`). The new spec omits `lazy`, but `meta.lua:195` chains fragments by `__index`, so `plugin.lazy` is still `true` from the extra and `plugin.lua:235` never applies `defaults.lazy = false`.

## Q3 — `vim.opt.formatoptions:remove` scope

**Label: ISSUE — `mini-comment.lua:18-23`.** `vim.opt` is `:set`, not `:setlocal`: `_options.lua:926` `vim.opt = create_option_accessor()` (no scope) → `_options.lua:716` `api.nvim_set_option_value(self._name, value, { scope = scope })` with `scope = nil`. `lua.txt:1315-1317`: "to replicate the behavior |:setlocal|, use `vim.opt_local`". `options.txt:233-235`: "With ":set" both the local and global value is changed. With "setlocal" only the local value is changed".

So it *does* strip `c,r,o` for the current buffer (ordering is fine: `autocmd.txt:237` BufEnter is "After |BufReadPost|", and FileType/ftplugin runs inside BufReadPost; `ftplugin/c.lua` never touches `formatoptions`), **but it also overwrites the global default with that buffer's flags**. Concrete leak: `ftplugin/typescript.vim:17` `setlocal formatoptions-=t formatoptions+=croql` — after visiting any `.ts`/`.tsx` buffer, the global loses `t` for every buffer opened afterwards. Flags are also reordered on every write (`_options.lua:411-418` concatenates `pairs` order), which matches the observed `"jtqnl"`.

The proposed `FileType` + `vim.opt_local` is **better** and order-safe: `starting.txt:458` step 6 "Enable filetype and indent plugins" runs *before* step 7 "Load user config", so the `filetypeplugin` augroup (`ftplugin.vim:12-13`) is registered first and `autocmd.txt:49-50` ("execute in the order in which they were defined") guarantees the user's handler runs after the ftplugin. It is **worse** in one case: buffers that never fire `FileType` (`[No Name]`, `:enew`) keep the global `c,r,o` — today's `BufEnter` covers them. It also stops re-firing on window switches (a win: one write per buffer instead of one per entry).

**Counter-argument:** the global pollution is invisible day-to-day because most ftplugins do not change `fo`. It still stands — `typescript.vim:17` is in the user's daily filetype set, and a `:set` write of buffer state into a global default is a defect regardless of blast radius.

## Q4 — Autocmds inside the `opts` table

**Label: ISSUE — `mini-comment.lua:11,18`.** Spec modules are executed at parse time: `plugin.lua:157-159` `local mod, err = loadfile(modpath) ... local ret, foo = mod()`, called from `Spec:import` during `require("lazy").setup()`. The module body — including both `nvim_create_autocmd` calls — therefore runs unconditionally, before any per-plugin `enabled`/`cond` evaluation and regardless of `event = "VeryLazy"`. With `enabled = false` on the spec the autocmds would still be created.

Worse: `change_detection` is on by default (`config.lua:188-190`) and the user's `lua/config/lazy.lua` does not disable it; a config edit runs `reloader.lua:101` `Plugin.load()` → `plugin.lua:326,335` `Spec.new()` / `parse` → `plugin.lua:184-186` clears `package.loaded[modname]` and re-runs the module. With no augroup, **duplicate autocmds accumulate on every reload**.

The stray `[1]`,`[2]` integer keys (autocmd ids) reach `MiniComment.setup` and are silently kept: `comment.lua:412` `vim.tbl_deep_extend('force', ...)` then only named-key checks, e.g. `comment.lua:415` `H.check_type('options.custom_commentstring', ..., 'function', true)` — no unknown-key validation.

**Counter-argument:** "side effects in a spec table are ugly but harmless." Not here: the reload path duplicates them, so the concern stands.

## Q5 — Commentstrings under each mechanism

**Label: ISSUE — `mini-comment.lua:7-9`** (the override suppresses all context awareness; `comment.lua:461-462` `cs = custom(...)`, `cs = cs or MiniComment.get_commentstring(...)` — a non-nil return means mini's own treesitter walk at `comment.lua:382-399` never runs).

| Case | With LazyVim's function (after fix) | Mechanism / line | With current override |
|-|-|-|-|
| (a) TSX in JSX markup | `{/* %s */}` | ts-context node walk, `config.lua:109` `jsx_element = '{/* %s */}'` via `internal.lua:131-135` | `// %s` (`typescript.vim:22`, sourced by `typescriptreact.vim:9`) — broken |
| (b) HTML in `<style>` | `/* %s */` | ts-context deepest-tree pick (`utils.lua:104-112`, children after parents per `languagetree.lua:648-655`) → `config.lua:68` `css` | `<!-- %s -->` — broken |
| (c) Markdown in ```lua fence | `-- %s` | ts-context `config.lua:82` `lua.__default` | `<!-- %s -->` — broken |
| (d) C | `// %s` | `config.lua` `languages.c` override → `internal.lua:121-123` | `// %s` (already from `ftplugin/c.lua:2`) |

(b) and (c) would also be answered correctly by mini's own walk if `custom_commentstring` returned `nil`; (a) would **not** — it is node-level, not filetype-level, so keeping LazyVim's function has real value.

**Keeping LazyVim's function AND the C/C++ autocmd does not work:** `calculate_commentstring` returns non-nil `/* %s */`, so the `or vim.bo.commentstring` fallback in the extra (`extras/coding/mini-comment.lua:8`) is never evaluated. Overriding `languages.c` is the only working route.

## Q6 — `pattern = { "c", "cpp", "h", "hpp" }`

**Label: ISSUE (dead code) — `mini-comment.lua:12`.** `.hpp` maps to filetype `cpp` (`filetype.lua:347` `hpp = 'cpp'`) and `.h` to `detect.header` (`filetype.lua:561`), which returns `objc`/`objcpp`/`c`/`ch`/`cpp` — `detect.lua:719` `return 'cpp'` by default. No buffer ever has filetype `h` or `hpp`, so those two patterns never match.

The autocmd is redundant in full: `ftplugin/c.lua:2` `vim.bo.commentstring = '// %s'` and `ftplugin/cpp.vim:17` `setlocal commentstring=//\ %s` already set it, and per Q5 setting `vim.bo.commentstring` cannot defeat ts-context anyway. It has **no remaining purpose**.

**Counter-argument:** it would matter if some later plugin reset `commentstring`; nothing in this config does (ts-context's own FileType hook only records the original — `internal.lua:17` — and its CursorHold updater is disabled). Stands.

## Verdict: INCOMPLETE (minor)

The fix is correct on both substantive defects: deleting the override restores node-aware commentstrings (Q5), `languages = { c = "// %s" }` is the only mechanism that actually reaches the C decision (Q1, Q5) and merges cleanly with `enable_autocmd = false` while staying lazy (Q2), and `vim.opt_local` stops the global `formatoptions` pollution (Q3). The one gap: switching `BufEnter` → `FileType` drops coverage for buffers that never fire `FileType` (`[No Name]`, `:enew`), where the default `'comments'` still lets `o`/`r` continue `#`, `//`, `>` lines. Listen for both events — both fire after the ftplugin, so ordering is safe either way:

```lua
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
  group = vim.api.nvim_create_augroup("user_no_comment_continue", { clear = true }),
  callback = function()
    vim.opt_local.formatoptions:remove({ "c", "r", "o" })
  end,
  desc = "Disable new line comment continuation",
})
```

(`pattern = "*"` is the default and can be dropped. The `clear = true` augroup also makes the handler idempotent across config reloads — the current file's un-grouped autocmds are not.)

---

**Verified this session:** `/Users/zcu/.config/nvim/lua/misc/mini-comment.lua:1-26`; `/Users/zcu/.config/nvim/lua/config/lazy.lua:1-58`; `/Users/zcu/.config/nvim/lazyvim.json:1-24`; `LazyVim/lua/lazyvim/plugins/extras/coding/mini-comment.lua:1-20`; `LazyVim/lua/lazyvim/config/options.lua:75`; `LazyVim/lua/lazyvim/config/init.lua:175-196,285-306`; `LazyVim/lua/lazyvim/config/autocmds.lua` (no `formatoptions` match); `mini.comment/lua/mini/comment.lua:359-402,410-431,459-482`; `nvim-ts-context-commentstring/lua/ts_context_commentstring/config.lua:48-158`, `internal.lua:1-140`, `utils.lua:56-116`, `ts_context_commentstring.lua:1-27`, `plugin/ts_context_commentstring.lua:1-30`; `lazy.nvim/lua/lazy/init.lua:79-87`, `core/plugin.lua:118-212,214-243,322-343,423-486`, `core/loader.lua:180-200,313-421,531-574`, `core/util.lua:68-71,155-165,440-470`, `core/meta.lua:168-209`, `core/config.lua:188-192,340-346`, `manage/reloader.lua:33-105`; nvim 0.11.4 runtime `ftplugin/c.lua:1-14`, `ftplugin/cpp.vim:1-24`, `ftplugin/lua.lua:1-11`, `ftplugin/typescript.vim:1-46`, `ftplugin/typescriptreact.vim:1-34`, `ftplugin.vim:6-39`, `lua/vim/filetype.lua:347,561`, `lua/vim/filetype/detect.lua:704-721`, `lua/vim/_options.lua:160-205,241-272,392-420,690-761,922-932`, `lua/vim/treesitter/languagetree.lua:648-656`, `doc/lua.txt:1230-1319`, `doc/options.txt:205-275`, `doc/autocmd.txt:44-53,188-237,268-314`, `doc/starting.txt:452-513`; parser inventory `/Users/zcu/.local/share/nvim/site/parser/*.so` (includes `c`, `cpp`, `tsx`, `css`, `html`, `lua`, `markdown`).

**Not verified this session:** the headless-run values supplied in the task prompt (`vim.o.formatoptions == "jtqnl"` at startup) — no nvim run was permitted; the value is consistent with `_options.lua:411-418` flag reordering plus the `c,r,o` removal, but I did not reproduce it.
