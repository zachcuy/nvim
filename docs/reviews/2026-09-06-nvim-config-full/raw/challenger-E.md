## M17: DOWNGRADED to LOW
Original: Angular extra enabled while `angularls = false`; `ngserver` installed but dropped from `ensure_installed`.
Verdict: DOWNGRADED to LOW

### Evidence
LazyVim `lua/lazyvim/plugins/lsp/init.lua:250-255`:
```lua
        sopts = sopts == true and {} or (not sopts) and { enabled = false } or sopts --[[@as lazyvim.lsp.Config]]
        if sopts.enabled == false then
          mason_exclude[#mason_exclude + 1] = server
          return
        end
```
`:270-275` — `install` = `vim.tbl_filter(configure, ...)` then `ensure_installed = install ...`, `automatic_enable = { exclude = mason_exclude }`.
mason-lspconfig `features/automatic_enable.lua:26-28,47`: `if _.any(_.equals(lspconfig_name), exclude) then return end` … `vim.lsp.enable(lspconfig_name)`.
LazyVim `util/init.lua:262-273`: path is built by string concat; missing path only triggers a scheduled `M.warn`, never an error.

### Reasoning
The mechanism is exactly as claimed: `angularls = false` drops it from `ensure_installed` AND lands it in `mason_exclude`, so mason-lspconfig does not `vim.lsp.enable` it. Nothing is broken today — `angular.so` exists (`~/.local/share/nvim/site/parser/angular.so`) and the vtsls plugin path resolves (`mason/packages/angular-language-server/node_modules/@angular/language-server/package.json`), so `get_pkg_path`'s `fs_stat` check passes and no warning fires. The only real costs are latent: on a fresh machine (this branch is `macbook-reset`) the package is never installed, so `get_pkg_path` warns on every lspconfig load and the vtsls plugin entry points at a missing path (vtsls's handling of that is external and unread). That is a documentation/intent gap, not a MEDIUM defect.

### Fix Assessment
Option 1 (comment recording intent) is correct and sufficient. Option 2 as written is a **bug**: deleting `lua/langs/lsp.lua` and disabling the extra removes `angularls` from `opts.servers`, so it never reaches `configure()`, never enters `mason_exclude`, and `automatic_enable.init()` (`automatic_enable.lua:54-56`, iterating `registry.get_installed_package_names()`) would call `vim.lsp.enable("angularls")` against the still-installed package using `nvim-lspconfig/lsp/angularls.lua` — re-enabling the LSP the user deliberately disabled. Option 2 must also `:MasonUninstall angular-language-server`, and must state that it drops the `angular`/`scss` parsers plus the `*.component.html` autocmd (angular.lua:11-24) and the vtsls `@angular/language-server` plugin (:48-59); the typescript extra survives independently of the angular extra's `{ import = ... }` because `lazyvim.json:14` lists `"lazyvim.plugins.extras.lang.typescript"` itself.

Counter-argument: one could call an installed-but-never-started LSP package plus a fresh-install warning a MEDIUM. It still stands as LOW because zero current behavior is wrong and the fix is a comment; the fresh-install warning is a notification, not a failure.

---

## M18: DOWNGRADED to LOW
Original: `lua/search/grug-far.lua` duplicates LazyVim's spec; `headerMaxWidth` is not a grug-far option.
Verdict: DOWNGRADED to LOW

### Evidence
Case-insensitive grep for `headerMaxWidth` across `~/.local/share/nvim/lazy/grug-far.nvim` (lua/ + doc/): **no matches**. Merge is non-validating — `grug-far/opts.lua:1015`: `local newOptions = vim.tbl_deep_extend('force', vim.deepcopy(defaults), options)`.
lazy.nvim `core/util.lua:338-348` `M.extend` dedups by value, so `cmd = "GrugFar"` cannot remove `"GrugFarWithin"`.
lazy.nvim `core/handler/keys.lua:49-51`: `if ret.mode ~= "n" then ret.id = ret.id .. " (" .. ret.mode .. ")" end` → ids `<leader>sr (x)` and `<leader>sr (v)` coexist.

### Reasoning
Every structural claim verifies. `headerMaxWidth` is inert but it is **LazyVim's own stale option** (`plugins/editor.lua:6`) — deleting the user file does not remove it, so it is not a user defect. The single functional delta is `mode` `"v"` (visual + select) vs `"x"` (visual only): `<leader>sr` becomes bound in select mode, so `<Space>` typed over a selected `vim.snippet` placeholder waits `timeoutlen` (300 ms, runtime-facts) instead of replacing the selection, and `<Space>sr` opens grug-far there. Everything else — `cmd`, the keys function, `opts` — is byte-identical to upstream. That is a maintenance-drift nit plus one 300 ms select-mode edge case, not MEDIUM.

### Fix Assessment
"Delete the file" is correct and safe: `GrugFar`, `GrugFarWithin`, the identical keymap function and `headerMaxWidth` all survive from LazyVim's spec; the only loss is the unintended select-mode binding. Note for the report: both `(x)` and `(v)` entries live in the same hash table keyed by id (`keys.lua:74-86`, `values[keys.id] = keys`), so x-mode ends up with whichever entry the handler sets last — iteration order not traced here; select mode always gets the user's copy. Harmless today since both stubs load the same plugin.

Counter-argument: a verbatim upstream copy will silently diverge when LazyVim changes the spec, which argues MEDIUM. It stays LOW because divergence has not happened; if it does, the user's file is the stale side and x-mode may keep running the older function — a behavior drift, but no error and no data loss.

---

## M19: DOWNGRADED to LOW
Original: options.lua re-declares 14 LazyVim defaults, five comments contradict their values, several lines are dead.
Verdict: DOWNGRADED to LOW (and the finding **undercounts** the dead lines)

### Evidence
Load order proven — LazyVim `config/init.lua:296-300`: `_load("lazyvim.config." .. name)` … then `_load("config." .. name)`; user values win, so identical values are pure no-ops.
All 15 cited lines match LazyVim `config/options.lua` verbatim in value: relativenumber :88, number :85, expandtab :62, smartindent :99, completeopt :58, wrap :115, linebreak :82, undofile :109, ignorecase :78, termguicolors :107, signcolumn :97, spelllang :101, splitright :104, splitbelow :102.
`options.txt:4388`: `'number' 'nu'		boolean	(default off)` → `vim.opt.nu` (user :55) is the same option as :9.
`diagnostic.lua:418` `local diagnostic_disabled = {}` and `:2496-2501` (`enable` with no bufnr/ns sets `diagnostic_disabled = {}`) → user :135 is a no-op.

### Reasoning
Every zero-delta claim holds, and three more no-ops exist that the finding missed: `options.txt:842` `'backup' (default off)`, `:3233` `'hlsearch' (default on)`, `:760` `'autoread' (default on)` — user :84, :93, :114 restate nvim defaults that LazyVim never touches. Total inert: 15 lines restating LazyVim values (the 14 above plus `nu` :55, which is `number` again) + `cursorcolumn` :12 + `diagnostic.enable(true)` :135 + `guicursor = ""` :18 (overwritten at :28) + 3 netrw vars :46/:49/:52 (dead after `loaded_netrw = 1`) + 3 nvim defaults :84/:93/:114 = **24** of 142 lines. Behavior change from removing all of them: **zero**. The six wrong comments are the real cost (they invite a wrong future edit: ":63 Use actual tabs" over `expandtab = true` is the dangerous one), but wrong comments in a personal config are LOW, not MEDIUM.

### Fix Assessment
"Keep only genuine deltas" is right but over-deletes if applied blind. The deltas that must be preserved: `tabstop`/`softtabstop = 4`, `shiftwidth = 0` (options.txt:5399 default 8, LazyVim 2), `breakindent = true` (:1103 default off), `swapfile = false` (:6196 default on), `scrolloff = 3` (LazyVim 4), `cursorline = false` (LazyVim true), `updatetime = 50` (LazyVim 200), `sessionoptions` **without** `"folds"` (LazyVim :91 includes it — an unlabeled delta that disables fold restore in persistence.nvim sessions; confirm intent before keeping or dropping), `iskeyword:append("-")`, `isfname:append("@-@")`, the guicursor block :21-39, `python3_host_prog`, `loaded_perl_provider`, `loaded_netrw*`, `snacks_animate = false`, `autoformat = false`, `mkdp_auto_close = 0`.

Counter-argument: contradictory comments have burned people before, which argues MEDIUM. It stays LOW because no line changes runtime behavior and no user-visible defect exists — this is documentation debt inside a config file.

---

## M20: DOWNGRADED to LOW
Original: Missing `desc` on leader-prefixed keymaps (`<leader>o`, `<leader>e`, `<leader>j`, ten `<leader>z*`).
Verdict: DOWNGRADED to LOW (count is also wrong: five `<leader>z*`, not ten)

### Evidence
which-key `view.lua:174-179`:
```lua
  if not desc and node.keymap and node.keymap.rhs ~= "" and type(node.keymap.rhs) == "string" then
    desc = node.keymap.rhs --[[@as string]]
  end
  if not desc and opts.default == "count" and child_count > 0 then
    desc = child_count .. " keymap" .. (child_count > 1 and "s" or "")
```
`node.lua:53-69` — `node.desc` resolves through `mapping`/`keymap`, so no `desc` ⇒ `nil`.
`tree.lua:62-69` `M:keep` returns true for `node.keymap or (node.mapping and not node.group)` — entries are never hidden for lacking `desc`.
`multicursor.lua:19-33` contains five `<leader>z*` maps (`zn zs zN zS zr`); lines 36-41 are `<c-leftmouse>`, `<c-leftdrag>`, `<c-leftrelease>`, `<c-q>` — not leader maps.

### Reasoning
Both `nvim_get_keymap` shapes for Lua callbacks resolve the same way: `rhs == ""` → `buf.lua:127` nop branch sets `node.mapping` (no `node.keymap`), so view.lua:175 is skipped; `rhs == nil` → the `type(...) == "string"` guard fails. Either way the five `<leader>z*` entries render as visible keys with an **empty** description, and `<leader>z` itself renders as "5 keymaps" because LazyVim registers no `<leader>z` group (`editor.lua:68-83` lists tabs/c/d/f/g/q/s/u/x/[/]/g/gs/z, no `<leader>z`). The three string-rhs maps degrade gracefully instead: `<leader>o`/`<leader>e` display `:Oil<Return>` and `<leader>j` displays `*``cgn`. Nothing is hidden or broken — worst case is 5 blank labels under an unnamed group.

### Fix Assessment
Adding `desc` is correct and risk-free. Two corrections for the report: (1) it is five `<leader>z*` maps, not ten; (2) also add `{ "<leader>z", group = "multicursor" }` to which-key's `spec` (LazyVim `editor.lua:68-83` pattern), otherwise the group header stays "5 keymaps" even after every leaf gets a `desc`. Do not add `desc` to the `<c-*>` maps as part of this — they are single complete keys, so they never sit under any leader group.

Counter-argument: the guide says "Always include `desc`", so a violation of a stated project rule could be MEDIUM. It stays LOW because which-key still lists every affected key, three of the eight show usable text, and the impact is label cosmetics with zero functional consequence.
