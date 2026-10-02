---
title: Cross-review challenger J1 verdicts
created: 2026-09-06
updated: 2026-09-06
status: final
topics:
  - code-review
  - nvim-config
---

## H6: DOWNGRADED to MEDIUM
Original: `vim.keymap.del` at keymaps.lua:53-54/108-109 can abort the rest of the file.
Verdict: DOWNGRADED to MEDIUM

### Evidence
`~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/init.lua:287-292` —
```lua
  local function _load(mod)
    if require("lazy.core.cache").find(mod)[1] then
      LazyVim.try(function()
        require(mod)
      end, { msg = "Failed loading " .. mod })
```
`~/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/util.lua:135-136` — `local ok, result = xpcall(fn, error_handler)` / `return ok and result or nil` (no rethrow; handler at :127-129 does `vim.schedule(function() M.error(msg) end)`).
`~/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/loader.lua:61` — `Handler.setup()` is the last statement of `Loader.setup()`; `~/.local/share/nvim/lazy/lazy.nvim/lua/lazy/init.lua:102,112` — `Loader.setup()` then, 10 lines later, `Loader.startup()` ("load plugins with lazy=false or Plugin.init").
`~/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/handler/event.lua:66-72` — `function M:_add(event)` … `vim.api.nvim_create_autocmd(event.event, { group = self.group, once = true, pattern = event.pattern, …})`.
`~/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/handler/keys.lua:82-86` — `if keys.rhs == vim.NIL or keys.rhs == false then values[keys.id] = nil else values[keys.id] = keys end`.
`~/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/plugin.lua:453,465` — `M._values(root, super.__index, ...)` then `Util.extend(ret, values)` (super = earlier fragment; later fragment appended).

### Reasoning
The abort mechanism is real, but the failure is **notified**, not silent (`M.error` via `vim.schedule`) — correct that word in the report. Two mitigations lower severity: (a) the mapping ordering is *structural*, not accidental — the event handler's `nvim_create_autocmd` for bufferline's VeryLazy hook is created by `Handler.setup()` at the end of `Loader.setup()` (loader.lua:61), which `lazy/init.lua:102` runs before `Loader.startup()` (:112) executes any plugin `config`; LazyVim's keymaps autocmd (config/init.lua:185-192, registered inside `M.setup`) is therefore always registered later and fires later, so the user override cannot lose to `_del`→`_set`; (b) both del targets provably exist today — bufferline's `keys` are materialized by `_set` at VeryLazy load, and `<leader>uz`/`<leader>uZ` are mapped synchronously by `Snacks.toggle.zoom():map("<leader>wm"):map("<leader>uZ")` (LazyVim config/keymaps.lua:202-203 → snacks toggle.lua:120 `self.opts.map(mode, keys, ...)`). Triggering E31 requires an upstream removal. Blast radius when triggered: keymaps.lua:55-109 = 9 `vim.keymap.set` calls lost (`<leader>bn`, `<leader>bp`, `<leader>r`, `S`, `q`, `<leader>j`, `<leader>yp`, `<leader>yP`, `<leader>cp`) plus the 2 deletions at :108-109 (`<leader>uz`/`<leader>uZ` stay mapped to Snacks zen/zoom). Latent + notified + needs upstream change = MEDIUM, not HIGH.

### Fix Assessment
Correct, and it also removes the `try`-abort exposure for lines 55-66. Verified prerequisites: list fragments concatenate in spec order (`lua/config/lazy.lua:20` LazyVim vs `:27` `ui`), later id wins, `false` deletes (keys.lua:82-86); `{ lhs, false }` precedent at `lua/misc/flash.lua:9`. Two notes: LazyVim already ships `[B`/`]B` for MovePrev/MoveNext (plugins/ui.lua:16-17), so the new entries are additive aliases, not the only path; and for `:108-109` `pcall` is the right shape — Snacks toggles are not `keys` entries, so no spec override can suppress them.

Counter-argument: one could argue HIGH because the whole file silently degrades. It still stands as MEDIUM: the error is surfaced by `M.error`, the trigger is an upstream regression rather than a user action, and the ordering that makes the override win is guaranteed by lazy.nvim's setup/startup split, not by luck.

## M9: CONFIRMED
Original: oil delete-buffer cleanup at oil.lua:160-171 never matches buffers inside a deleted directory.
Verdict: CONFIRMED (MEDIUM)

### Evidence
`~/.local/share/nvim/lazy/oil.nvim/lua/oil/mutator/init.lua:172-178` —
```lua
      else
        -- DELETE when no create
        add_action({
          type = "delete",
          entry_type = entry[FIELD_TYPE],
          url = cache.get_parent_url(id) .. entry[FIELD_NAME],
```
`~/.local/share/nvim/lazy/oil.nvim/lua/oil/adapters/files.lua:621-625` —
```lua
    if config.delete_to_trash then
      require("oil.adapters.trash").delete_to_trash(path, cb)
    else
      fs.recursive_delete(action.entry_type, path, cb)
    end
```
`~/.local/share/nvim/lazy/oil.nvim/lua/oil/util.lua:270-289` — `update_moved_buffers` prefix-matches with `vim.startswith(bufname, src_buf_name)`.

### Reasoning
One `delete` action per removed oil line; recursion happens entirely below the action layer (`recursive_delete` / trash adapter), and `delete_to_trash` is consulted *inside* `perform_action` without changing `action.type` or emitting extra actions. So `canonical_path(name) == target` (oil.lua:168) can only ever match the directory's own path, never its descendants — buffers under a deleted directory survive, which is exactly the lingering-deleted-file stall the autocmd exists to prevent (oil.lua:136-139).

### Fix Assessment
Directionally correct, with one correction and one caveat. Correction: the *target* side is fine — `url` carries no trailing slash (`parent_url .. FIELD_NAME`), so `canonical_path` realpaths the still-existing grandparent normally. The unresolvable side is the *buffer* side: for a descendant, `fnamemodify(name, ":h")` is inside the deleted tree, `vim.uv.fs_realpath` returns nil, and oil.lua:149 falls back to `vim.fs.normalize(p)` — so a symlinked ancestor makes the prefix compare fail. A correct fix realpaths the nearest existing ancestor of the buffer name and rebuilds the tail. Separator guard: required, and oil's own `update_moved_buffers` (util.lua:285) omits it — treat that as precedent for the technique, not for the missing guard; without `target .. "/"` a delete of `/a/dir` would wipe buffers under `/a/dirsuffix`.

Counter-argument: with `delete_to_trash = true` the tree is recoverable, so stale buffers are less dangerous. It still stands: the autocmd's stated purpose is the ~1 s UI stall on returning to a missing-file buffer, and trash-vs-unlink does not change that the path is gone.

## M13: DOWNGRADED to MEDIUM
Original: C/C++ insert-mode `*` mapping (autocmds.lua:19-34) has three defects; proposed HIGH.
Verdict: DOWNGRADED to MEDIUM (proposed upgrade rejected; claim (2) partly wrong)

### Evidence
`runtime/doc/vimfn.txt:2204-2208` — "By default the string is added to the end of the typeahead buffer, thus if a mapping is still being executed the characters come after them.  Use the 'i' flag to insert before other characters"; `:2228` — "'i'	Insert the string instead of appending".
`runtime/doc/insert.txt:342-344` — "The changes (inserted or deleted characters) before and after these keys can be undone separately.  Only the last change can be redone"; `:382-384` — "CTRL-G U	don't start a new undo block with the next left/right cursor movement".
`runtime/lua/vim/treesitter.lua:259-265` — `get_captures_at_pos` exists; `if not buf_highlighter then return {} end`.

### Reasoning
Claim (1) is doc-correct but rate-limited: the transposition needs `*` and the following key inside the same input batch, so it is a fast-typing/scripted-input hazard, not a per-keystroke one. Claim (3) is deterministic — every `/*` expansion splits undo at the three bare `<Left>`s. Claim (2) is half wrong: `/**` cannot mis-expand, because after `/*` expands to `/* | */` the char before the cursor is a space, so the second `*` takes the else branch; the real false positives are a `/` immediately before a typed `*` inside a string (`"src/*.c"`) or an existing comment (`// http://x/*`). One certain defect plus one probabilistic one plus a narrow false-positive class = MEDIUM. The augroup and buffer-local-map-survives-`:set ft=` observations are accurate and additive.

### Fix Assessment
Correct in shape, with two caveats to state in the fix. (a) `expr = true` is safe here: `vim.keymap.set` sets `replace_keycodes = true` for expr maps (`runtime/lua/vim/keymap.lua:55-57`) so `<C-g>U<Left>` in the returned string is translated, and `opts.noremap = true` by default (:59-61) so it is not re-mapped. (b) The treesitter guard degrades open, not closed: with no active highlighter `get_captures_at_pos` returns `{}` (treesitter.lua:263-265), so the string/comment suppression silently does nothing on a buffer without TS highlighting — acceptable (matches today's behavior) but must not be described as a guarantee.

Counter-argument: pointer-heavy C means `int *p` is typed constantly, which argues for HIGH. It still stands at MEDIUM: `*` after a space takes the else branch, and that branch's only exposure is the same-batch typeahead race — the mapping does not corrupt ordinary dereference typing deterministically.

## M21: CONFIRMED
Original: `<leader>ba` = `:bufdo bd` uses `:bufdo` in a way the docs forbid.
Verdict: CONFIRMED (MEDIUM)

### Evidence
`runtime/doc/windows.txt:840-841` — "When an error is detected on one buffer, further buffers will not be visited."; `:846-847` — "{cmd} must not delete buffers or add buffers to the buffer list."
`~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/bufdelete.lua:96-101` — `M.all` = `M.delete{ filter = function() return true end }`; `:31-37` iterates `vim.tbl_filter(opts.filter, nvim_list_bufs())` calling `M.delete` per buffer.
`bufdelete.lua:54-57` — `if vim.bo[buf].modified and not opts.force then local ok, choice = pcall(vim.fn.confirm, ...) if not ok or choice == 0 or choice == 3 then return end`.

### Reasoning
`bd` is precisely the "must not delete buffers" case, and `:bufdo` halts on the first error, so any buffer that refuses deletion leaves every later buffer open — the mapping's stated purpose fails partway with no indication of how far it got. `Snacks.bufdelete.all()` iterates a snapshot of `nvim_list_bufs()` and the modified-buffer refusal is a plain `return` from the inner recursive `M.delete` (line 57), so the outer loop at :32-36 continues — no abort, and window layout is preserved (:77-84).

### Fix Assessment
Correct: `function() Snacks.bufdelete.all() end`. LazyVim binds only `<leader>bd` → `Snacks.bufdelete()`, `<leader>bo` → `.other()`, `<leader>bi` → `.invisible()` (config/keymaps.lua:40-48) and `<leader>bD` → `<cmd>:bd<cr>` (:49) — no `.all()` binding anywhere, so `<leader>ba` remains free and non-duplicative. Scope note: `M.all` deletes only `buflisted` buffers (:33), which is the desired semantics and a superset of what `:bufdo` visits ("Unlisted buffers are skipped", windows.txt:842).

Counter-argument: the exact claim that Cancel on the `'confirm'` dialog counts as a `:bufdo`-halting error is not something I could confirm from `options.txt:1640-1650`, which only says the dialog replaces the failure. I mark that sub-mechanism unverified; the verdict does not rest on it — the documented prohibition plus the plain `E89` path when the dialog is declined already establishes the halt.

## M22: DOWNGRADED to LOW (core claim DISMISSED)
Original: `<leader>cp` → `:LspStop` does not stop the running client; only disables configs globally.
Verdict: DOWNGRADED to LOW — the central claim is false on Neovim 0.11.4

### Evidence
`runtime/lua/vim/lsp.lua:624-630` —
```lua
  else
    for _, nm in ipairs(names) do
      for _, client in ipairs(lsp.get_clients({ name = nm })) do
        client:stop()
      end
    end
  end
```
`lsp.lua:589-590` — "@param enable? boolean `true|nil` to enable, `false` to disable (actively stops and detaches clients as needed)".
`~/.local/share/nvim/lazy/nvim-lspconfig/plugin/lspconfig.lua:173-181` — comment "Default to disabling all servers on current buffer" over `client_names = vim.iter(vim.lsp.get_clients()):map(...)` (no `bufnr` filter); this branch is live because the file gates on `if vim.fn.has('nvim-0.11.2') == 1 then` (:84) and returns at :202.
`lspconfig.lua:113-123` — `LspStart` with no args collects only configs whose `filetypes` contain `vim.bo.filetype`.

### Reasoning
`vim.lsp.enable(name, false)` *does* stop every matching client (lsp.lua:625-628); `:LspStop!`'s only addition is `client:stop(true)` (force) instead of graceful. So "the attached client keeps running" and "desc is wrong" both collapse — `Disable LSP` is a fair description of disable+stop. What survives: (a) no-arg `:LspStop` targets `vim.lsp.get_clients()` globally despite the in-source comment claiming current-buffer scope; (b) `_enabled_configs[nm] = nil` (:599) suppresses future auto-attach process-wide, while no-arg `:LspStart` re-enables only current-filetype servers (:113-123), making the round trip asymmetric; (c) `<leader>cp` is shadowed buffer-locally in markdown by LazyVim's markdown-preview key (extras/lang/markdown.lua:82-89 with `ft = "markdown"`; `ft` keys become buffer-local via handler/keys.lua:151-163). Three minor annoyances, no correctness bug → LOW.

### Fix Assessment
The proposed `:LspStop!` / `vim.lsp.stop_client(...)` rebinding is not needed for stopping. If the scope asymmetry is worth fixing, the accurate fix is `:LspStop <name>`-style targeting via `vim.lsp.get_clients({ bufnr = 0 })` names, or leaving `:LspStop` and accepting global scope. Do **not** ship the fix on the "doesn't stop" rationale — that rationale is wrong and would put an incorrect claim in the review. The markdown shadow is real and worth a one-line note.

Counter-argument: the review could argue the *global* disable is itself severe because a `<leader>cp` in one buffer kills LSP everywhere. It still stands at LOW: that is the documented behavior of `:LspStop` upstream, it is user-initiated, and `:LspStart` per buffer recovers it.

## M23: CONFIRMED
Original: `"v"` mode on printable-key maps (keymaps.lua:42-43, :84) hijacks Select mode.
Verdict: CONFIRMED (MEDIUM)

### Evidence
`runtime/doc/map.txt:385` — ":vmap  :vnoremap :vunmap    Visual and Select"; `:424-426` — "NOTE: Mapping a printable character in Select mode may confuse the user.  It's better to explicitly use :xmap and :smap for printable characters."; `:369` — "For Select mode: like Visual mode but typing text replaces the selection."
`runtime/lua/vim/snippet.lua:319-326` — `local keys = { mode ~= 'n' and '<Esc>' or '', ('<Cmd>call cursor(%s,%s)<CR>')…, 'v', …, 'o<c-g><c-r>_' }` then `feedkeys(table.concat(keys))` — `<C-g>` switches the Visual selection into Select mode.
`~/.local/share/nvim/lazy/blink.cmp/lua/blink/cmp/config/snippets.lua:29-30` — `expand = by_preset({ default = function(snippet) vim.snippet.expand(snippet) end, …})`; config uses `preset = "default"` (LazyVim extras/coding/blink.lua).

### Reasoning
`"v"` covers Select, and `p`, `P`, `q` are printable, so in Select mode the maps intercept the keystroke that should replace the selection. Expected manifestation (derived from map.txt:369, not observed at runtime): typing `param` over a placeholder yields `Param` because the `p`→`P` map fires on the first char and the rest insert normally, and `q` is swallowed entirely by the `""` mapping. Select mode is reachable in this config on every non-empty snippet tabstop, since blink's default preset routes to `vim.snippet`, which enters Select mode via `o<c-g>`. LazyVim's own `"v"` maps are `<A-j>`/`<A-k>` (config/keymaps.lua:30-31) — non-printable, so there is no in-repo precedent for printable `"v"` maps.

### Fix Assessment
Correct: `"x"` for keymaps.lua:42-43 and `{ "n", "x" }` for :84. No new bug — Visual-mode behavior is byte-identical, and the visual `p`/`P` swap intent (avoid clobbering the unnamed register) is unaffected. Note that `<C-c>` at keymaps.lua:6 (`{ "n", "v" }`) is non-printable and therefore fine as-is; do not sweep it into the change.

Counter-argument: a user who never triggers a snippet placeholder never sees this, which argues for LOW. It still stands at MEDIUM: blink is the completion engine and snippet expansion is routine, the failure is silent text corruption inside a placeholder rather than an error, and the fix is a two-character edit.
