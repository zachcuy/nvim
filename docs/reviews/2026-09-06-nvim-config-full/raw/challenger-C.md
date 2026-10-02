## M6: DOWNGRADED to LOW
Original: `<C-k>` signature-help key is inert; falls through to the digraph key.
Verdict: DOWNGRADED to LOW

### Evidence
LazyVim binds insert-mode `<c-k>` to LSP signature help for every server (`servers["*"]`, lsp/init.lua:68):
```lua
-- LazyVim/lua/lazyvim/plugins/lsp/init.lua:87
{ "<c-k>", function() return vim.lsp.buf.signature_help() end, mode = "i", desc = "Signature Help", has = "signatureHelp" },
```
```lua
-- LazyVim/lua/lazyvim/plugins/lsp/init.lua:175
require("lazyvim.plugins.lsp.keymaps").set({ name = server ~= "*" and server or nil }, server_opts.keys)
```
That path ends in a real buffer-local map (snacks.nvim/lua/snacks/keymap.lua:89, hooked up at :166-171 via `Snacks.util.lsp.on`):
```lua
-- snacks/keymap.lua:87-90
if matches[lkey] then
  done[map.key] = true
  vim.keymap.set(map.mode, map.lhs, map.rhs, Snacks.config.merge(map.opts or {}, { buffer = buf }))
```
blink captures that pre-existing buffer map *before* overwriting it, and runs it on `fallback`:
```lua
-- blink.cmp/lua/blink/cmp/keymap/apply.lua:50-51
local fallback = require('blink.cmp.keymap.fallback').wrap('i', key)
apply.set('i', key, function()
```
```lua
-- blink.cmp/lua/blink/cmp/keymap/fallback.lua:57-61
local buffer_mapping = mode ~= 'c' and fallback.get_non_blink_buffer_mapping_for_key(mode, key) ...
  local mapping = buffer_mapping or fallback.get_non_blink_global_mapping_for_key(mode, key)
  if mapping then return fallback.run_non_blink_keymap(mapping, key) end
```
The user's line is a byte-for-byte copy of the `default` preset (blink.cmp/lua/blink/cmp/keymap/presets.lua:23):
`['<C-k>'] = { 'show_signature', 'hide_signature', 'fallback' },`

### Reasoning
`signature.enabled = false` (config/signature.lua:33) and the early return in `cmp.show_signature` (init.lua:308) are both real, so blink's own signature window never opens — but "the key is inert" is false. In any buffer with an LSP client advertising `textDocument/signatureHelp`, `<C-k>` reaches `vim.lsp.buf.signature_help()`, either via blink's captured fallback (LspAttach first) or because Snacks' buffer-local map overwrote blink's (InsertEnter first). Only in non-LSP buffers does it fall to the digraph key — which is vanilla Neovim behavior, not a regression. Residuals: blink.lua:7 is a zero-delta duplicate of the preset (dead line), and the docs' "toggle signature help" overstates `vim.lsp.buf.signature_help()`, which shows but never hides.

### Fix Assessment
Both draft fixes are wrong. (1) `signature = { enabled = true }` is a behavior change, not a repair: `show_signature` would then return `true` (init.lua:310), short-circuiting the LSP fallback, and `trigger.enabled = true` / `show_on_trigger_character = true` (signature.lua:35,39) turn on an auto-popup the user never asked for. (2) "Delete the key" is a no-op — the `default` preset re-adds it (presets.lua:23, merged at keymap/init.lua:50-58); only `["<C-k>"] = false` removes it (keymap/init.lua:63-65). "Delete the doc rows" would delete docs for a key that works. Correct fix: drop the redundant line 7 only if you also want blink out of the way, and reword docs/specs/plugins.md + keymaps.md from "toggle signature help" to "LSP signature help (show only)".

Counter-argument: if a user never runs an LSP, `<C-k>` really is just the digraph key and the docs are wrong. Still LOW — that is Neovim's default in a bufferless/non-LSP context, and the config introduces no breakage there.

---

## M7: CONFIRMED
Original: `<leader>cp` is LspStop globally but Markdown Preview inside markdown buffers.
Verdict: CONFIRMED (MEDIUM)

### Evidence
```lua
-- lua/config/keymaps.lua:106
keymap.set("n", "<leader>cp", ":LspStop<Return>", { noremap = true, silent = true, desc = "Disable LSP" })
```
```lua
-- LazyVim/lua/lazyvim/plugins/extras/lang/markdown.lua:82-88
keys = {
  { "<leader>cp", ft = "markdown", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview" },
},
```
lazy.nvim makes that buffer-local on FileType, both before and after the plugin loads:
```lua
-- lazy.nvim/lua/lazy/core/handler/keys.lua:151-161
if keys.ft then
  vim.api.nvim_create_autocmd("FileType", { pattern = keys.ft, callback = function(event)
    if self.active[keys.id] and not M.is_nop(keys) then add(event.buf)
    else self:_set(keys, event.buf) end
```
Pre-load placeholder is buffer-scoped (`buffer = buf`, keys.lua:146); post-load real map is too (`opts.buffer = buf`, keys.lua:197).

### Reasoning
Both branches produce a buffer-local `<leader>cp` in markdown buffers, and buffer-local always beats the global map from keymaps.lua:106. The collision is real and silent. One framing correction: the draft's premise that `:LspStop` may be cosmetic because "`vim.lsp.enable` re-attaches on the next buffer" is false — `lsp.enable(name, false)` clears `_enabled_configs[nm]` (nvim 0.11.4 lsp.lua:599) *and* stops clients (`for _, client in ipairs(lsp.get_clients({ name = nm })) do client:stop() end`, lsp.lua:625-629), and `lsp_enable_callback` only starts configs still in `_enabled_configs` (lsp.lua:535-537). A separate real inaccuracy: lspconfig/plugin/lspconfig.lua:173 comments "Default to disabling all servers on current buffer" but line 176 calls `vim.lsp.get_clients()` with no `bufnr` filter, so `<leader>cp` disables and stops *every* client in the session, not just the current buffer's. The `desc = "Disable LSP"` is therefore under-stated, not over-stated.

### Fix Assessment
Correct. Moving LspStop to a free key resolves it with no side effects. Alternative if the user prefers keeping `<leader>cp` for LspStop: add a markdown-preview spec with `keys = { { "<leader>cp", false } }` — handler/keys.lua:82 drops entries whose `rhs` is `false`, so the buffer-local map is never created. Either way, docs/specs/keymaps.md needs the markdown-preview row it currently lacks.

Counter-argument: a user who only previews markdown and never stops an LSP in markdown files feels nothing. But the global map's `desc` lies in markdown buffers and which-key shows only the buffer-local entry, so the collision is undiscoverable — MEDIUM stands.

---

## M8: CONFIRMED
Original: Oil's `"<Nop>"` for `<C-h>`/`<C-t>` creates a buffer-local no-op that shadows window navigation.
Verdict: CONFIRMED (MEDIUM)

### Evidence
`resolve()` gives strings no special treatment — `"<Nop>"` is not `actions.*` and not a table, so it falls to the terminal branch:
```lua
-- oil.nvim/lua/oil/keymap_util.lua:60-62
  else
    return rhs, {}
  end
```
```lua
-- oil.nvim/lua/oil/keymap_util.lua:69-72
local rhs, opts, mode = resolve(v)
if rhs then
  vim.keymap.set(mode or "", k, rhs, vim.tbl_extend("keep", { buffer = bufnr }, opts))
```
Oil documents `false` as the disable idiom, and the defaults being replaced:
```lua
-- oil.nvim/lua/oil/config.lua:58,64-65
  -- Set to `false` to remove a keymap
    ["<C-h>"] = { "actions.select", opts = { horizontal = true } },
    ["<C-t>"] = { "actions.select", opts = { tab = true } },
```
```lua
-- oil.nvim/lua/oil/config.lua:411-412
    for k, v in pairs(opts.keymaps) do
      new_conf.keymaps[k] = v
```
```lua
-- LazyVim/lua/lazyvim/config/keymaps.lua:14
map("n", "<C-h>", "<C-w>h", { desc = "Go to Left Window", remap = true })
```

### Reasoning
Per-key override (config.lua:412) replaces oil's default with the string `"<Nop>"`, which is truthy, so `vim.keymap.set("", "<C-h>", "<Nop>", { buffer = bufnr })` runs — mode `""` covers n/v/s/o. LazyVim's `<C-h>` is a plain global normal-mode map, so the buffer-local no-op wins inside oil buffers and window-left navigation dies there. `false` reaches the same declared intent ("disable open in horizontal split window") while letting the global map through.

### Fix Assessment
Correct, no new bugs. `false` also keeps `show_help` clean (keymap_util.lua:81 skips falsy entries), which `"<Nop>"` does not — today `g?` lists `<C-h>`/`<C-t>` with an empty description. For `<C-t>`, `false` restores Neovim's built-in tag-stack pop in oil buffers; LazyVim maps no global `<C-t>` (grep of config/keymaps.lua: no match), so nothing else changes.

Counter-argument: someone could want `<C-h>` deliberately dead inside oil to avoid mis-navigation. The inline comment states the intent is disabling oil's split/tab open, not blocking window motion, so `false` matches intent; a deliberate block would need an explicit `<Nop>` comment saying so.

---

## M10: CONFIRMED (severity MEDIUM) — draft fix is broken
Original: Oil `gs` calls two deprecated grug-far functions.
Verdict: CONFIRMED, but the proposed fix introduces a runtime error and must be replaced.

### Evidence
```lua
-- grug-far.nvim/lua/grug-far.lua:501-503
function grug_far.open_instance(instQuery)
  vim.deprecate('open_instance(...)', 'get_instance(...):open()', 'soon', 'grug-far.nvim')
```
```lua
-- grug-far.nvim/lua/grug-far.lua:515-522
function grug_far.update_instance_prefills(instQuery, prefills, clearOld)
  vim.deprecate('update_instance_prefills(...)', 'get_instance(...):update_input_values()', 'soon', 'grug-far.nvim')
  grug_far.get_instance(instQuery):update_input_values(prefills, clearOld)
```
The instance API has no `update_prefills`; the method is:
```lua
-- grug-far.nvim/lua/grug-far/instances.lua:397-399
---@param values grug.far.Prefills
---@param clearOld boolean
function inst:update_input_values(values, clearOld)
```
`inst:open()` exists (instances.lua:337). `has_instance` (grug-far.lua:412) and `grug_far.open` (grug-far.lua:260) are above the `-- deprecated API` divider at :472 — not deprecated. Current upstream README shows exactly this oil recipe: `grug_far.get_instance('explorer'):open()` / `:update_input_values(prefills, false)` (README.md:507-509).
Warnings are suppressed for this user: `vim.deprecate` with `plugin ~= 'Nvim'` takes the `vim.notify_once` branch (nvim 0.11.4 _editor.lua:1373-1386), but LazyVim replaces the function outright:
```lua
-- LazyVim/lua/lazyvim/config/init.lua:343-345
  if vim.g.deprecation_warnings == false then
    vim.deprecate = function() end
  end
```
with `vim.g.deprecation_warnings = false` at LazyVim/lua/lazyvim/config/options.lua:46 and no override anywhere in /Users/zcu/.config/nvim/lua.

### Reasoning
The deprecation is real and both calls are in the live `gs` else-branch (lua/ui/oil.lua:94,96). The draft's replacement `:update_prefills(prefills, false)` names a method that does not exist on the instance class, so applying it turns a working deprecated call into `attempt to call a nil value (method 'update_prefills')` on every second `gs` press — strictly worse than the status quo. Severity stays MEDIUM rather than dropping to LOW: current user-visible impact is zero *because* the warning is suppressed, which removes the only signal that would precede the break; when grug-far drops the shims ('soon', unbounded), `gs` on an existing instance hard-errors with no prior notice.

### Fix Assessment
Draft fix is wrong. Correct replacement for lua/ui/oil.lua:94-96:
```lua
local inst = grug_far.get_instance("explorer")
inst:open()
inst:update_input_values(prefills, false)
```
Argument order `(values, clearOld)` matches the old `(prefills, clearOld)`, so `false` keeps its meaning (instances.lua:399-403 → `inputs.fill(context, buf, values, clearOld)`). Binding the instance once avoids the double `get_instance` lookup in the README version; it is safe because the branch is guarded by `has_instance("explorer")` (oil.lua:87), and `get_instance` errors only when a non-nil query finds nothing (grug-far.lua:372-379). `inst:open()` is still required before `update_input_values` for focus, though `update_input_values` itself calls `ensure_open()` (instances.lua:400).

Counter-argument: with warnings suppressed and the shims still present, one could call this LOW/cosmetic. That argument is exactly why it should not be downgraded — the suppression guarantees the failure arrives unannounced, and the corrected fix is a three-line change.
