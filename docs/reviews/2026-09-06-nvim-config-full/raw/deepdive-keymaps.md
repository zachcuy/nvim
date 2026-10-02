---
title: Deep-dive review — lua/config/keymaps.lua lines 45-109 + bufferline keys fix
created: 2026-09-06
updated: 2026-09-06
status: final
topics:
  - keymaps
  - lazy-nvim
  - lazyvim
  - bufferline
  - lsp
---

# Deep-dive: `lua/config/keymaps.lua` 45-109

Scope: `/Users/zcu/.config/nvim/lua/config/keymaps.lua` lines 45-109 (plus lines 42-43 per Q5), and
the proposed relocation of lines 53-66 into `/Users/zcu/.config/nvim/lua/ui/bufferline.lua`'s `keys`.

Acronyms expanded on first use: LSP (Language Server Protocol), DAP (Debug Adapter Protocol).

---

## Q1 — `:bufdo bd` (keymaps.lua:50) — **ISSUE**

`/Users/zcu/.config/nvim/lua/config/keymaps.lua:50`

```lua
keymap.set("n", "<Leader>ba", ":bufdo bd<Return>", { noremap = true, silent = true, desc = "Delete all buffers" })
```

`:bufdo` explicitly forbids this command. `windows.txt:840-847`:

```
			When an error is detected on one buffer, further
			buffers will not be visited.
			Unlisted buffers are skipped.
			The last buffer (or where an error occurred) becomes
			the current buffer.
			{cmd} can contain '|' to concatenate several commands.
			{cmd} must not delete buffers or add buffers to the
			buffer list.
```

`:bd` semantics, `windows.txt:1171-1179`:

```
:[N]bd[elete][!]			*:bd* *:bdel* *:bdelete* *E516*
:bd[elete][!] [N]
		Unload buffer [N] (default: current buffer) and delete it from
		the buffer list.  If the buffer was changed, this fails,
		unless when [!] is specified, in which case changes are lost.
```

**(a) One buffer modified.** LazyVim sets `confirm = true` (options.lua:60, per the headless run).
`:bdelete` is a `:confirm`-covered command — `editing.txt:1244-1247`:

```
			|:edit|, |:q|, |:qa| and |:w| commands (the latter to
			override a read-only setting), and any commands that
			can fail because of unsaved changes, such as |:only|,
			|:buffer|, |:bdelete|, etc.
```

So Neovim prompts rather than immediately raising `E89`/`E37` (`message.txt:431-433`: "No write since
last change (add ! to override)"). But the prompt is per-buffer and blocking, and choosing
Cancel/Abandon-refusal makes `:bd` fail — which is "an error detected on one buffer", so
`windows.txt:840-841` halts iteration and every later buffer stays open.

**(b) Current buffer deleted mid-iteration.** `windows.txt:846-847` states the `{cmd}` "must not
delete buffers". `:bufdo` works like `:bfirst` / `:{cmd}` / `:bnext` (`windows.txt:832-837`); deleting
the buffer the iterator is positioned on invalidates that position. Behavior here is *unspecified by
the documentation*, not merely unverified — the doc prohibits the construct.

**(c) Special buffers.** `windows.txt:842` — "Unlisted buffers are skipped." Oil buffers are unlisted
by default: `/Users/zcu/.local/share/nvim/lazy/oil.nvim/lua/oil/config.lua:15` sets `buflisted = false`
inside `buf_options`, and `/Users/zcu/.config/nvim/lua/ui/oil.lua` contains no `buf_options` override
(grep for `buf_options|buflisted` returned no matches). So Oil buffers survive `<leader>ba`.
`'buflisted'` default is on (`options.txt:1164`), so terminal buffers are visited. Terminal-specific
`:bd` behavior is **not verifiable from the 0.11.4 runtime docs** (`terminal.txt` grep for
`buflisted|E947|still running` returned nothing; `nvim_terminal_emulator.txt` does not exist in this
runtime) and running nvim is out of scope — not asserted.

**Snacks provides the correct primitive.** `/Users/zcu/.local/share/nvim/lazy/snacks.nvim/lua/snacks/bufdelete.lua:94-102`:

```lua
--- Delete all buffers
---@param opts? snacks.bufdelete.Opts
function M.all(opts)
  return M.delete(vim.tbl_extend("force", {}, opts or {}, {
    filter = function()
```

`M.delete` handles the modified case with a non-aborting three-way prompt (bufdelete.lua:54-61) and
preserves window layout (bufdelete.lua:77-84).

**LazyVim binds neighbours but no delete-all.** `/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/keymaps.lua:43-49`:

```lua
map("n", "<leader>bo", function()
  Snacks.bufdelete.other()
end, { desc = "Delete Other Buffers" })
map("n", "<leader>bi", function()
  Snacks.bufdelete.invisible()
end, { desc = "Delete Invisible Buffers" })
map("n", "<leader>bD", "<cmd>:bd<cr>", { desc = "Delete Buffer and Window" })
```

`<leader>ba` therefore fills a genuine gap — the intent is right, the implementation is not. Fix:
`Snacks.bufdelete.all()`.

**Counter-argument:** "It works in practice — I press `<leader>ba` daily." Two rebuttals: the doc
prohibits the construct outright (`windows.txt:846-847`), so today's behavior is an implementation
accident, not a contract; and the failure mode is silent and partial (one modified buffer halts
iteration, leaving the rest open) — precisely the case where "it works" stops being observed. Stands.

---

## Q2 — Proposed `keys`-table fix — **NO ISSUE** (mechanism verified sound)

**Merge order.** `/Users/zcu/.config/nvim/lua/config/lazy.lua:20` (`{ "LazyVim/LazyVim", import = "lazyvim.plugins" }`)
precedes `:27` (`{ import = "ui" }`), so LazyVim's bufferline fragment is added before the user's.

**Fragment chaining.** `/Users/zcu/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/meta.lua:189-195`:

```lua
  for _, fid in ipairs(plugin._.frags) do
    if not added[fid] then
      added[fid] = true
      local fragment = self.fragments:get(fid)
      assert(fragment, "fragment " .. fid .. " not found, for plugin " .. name)
      super = setmetatable(fragment.spec, super and { __index = super } or nil)
```

Each later fragment becomes the outer `super`; earlier fragments sit deeper in the `__index` chain.

**List accumulation.** `/Users/zcu/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/plugin.lua:451-454`:

```lua
  local super = getmetatable(plugin)
  ---@type table
  local ret = super and M._values(root, super.__index, prop, is_list) or {}
  local values = rawget(plugin, prop)
```

and `plugin.lua:456-466`:

```lua
  if not values then
    return ret
  elseif type(values) == "function" then
    ret = values(root, ret) or ret
    return type(ret) == "table" and ret or { ret }
  end

  values = type(values) == "table" and values or { values }
  if is_list then
    return Util.extend(ret, values)
  else
```

Note the `elseif type(values) == "function"` branch at :458-461 — a function-valued `keys` *replaces*
rather than extends. Neither LazyVim's bufferline spec nor the proposed fix uses a function, so the
`is_list` branch at :464-465 is the live path here.

Super (= earlier fragment) is recursed first, then the current fragment's values are appended. So the
resulting list is LazyVim's keys, then the user's keys. `Util.extend`
(`/Users/zcu/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/util.lua:338-349`) dedupes by *table
identity* only (`idx[v] = v`), and the two specs are distinct tables, so nothing is dropped here.

**Dedup by id, later wins, `false` removes.** `/Users/zcu/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/handler/keys.lua:80-87`:

```lua
    for _, mode in ipairs(modes) do
      local keys = M.parse(value, mode)
      if keys.rhs == vim.NIL or keys.rhs == false then
        values[keys.id] = nil
      else
        values[keys.id] = keys
      end
```

`id` is `nvim_replace_termcodes(lhs)` plus a mode suffix when mode ~= "n" (keys.lua:42-51) — i.e.
lhs+mode. The keys handler overrides the generic `_values` at
`/Users/zcu/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/handler/keys.lua:67-69`:

```lua
function M:_values(values)
  return M.resolve(values)
end
```

which shadows the base implementation in `handler/init.lua:90-98`, and is reached from
`handler/init.lua:106` — `plugin._.handlers[type] = handler:_values(Plugin.values(plugin, type, true), plugin)`.

**Conclusion: the fix reproduces the current runtime state with zero `vim.keymap.del`.**
`<leader>bp` → the user's `BufferLineMovePrev` (later id wins over LazyVim's Toggle Pin at
`plugins/ui.lua:8`); `<leader>bP` → removed entirely by `{ "<leader>bP", false }` (keys.lua:82-83),
matching the observed `nil`; `<leader>bn` → `BufferLineMoveNext`. The mechanism is already proven in
this repo: `<Tab>`, `<S-Tab>`, `<leader>bs` at `lua/ui/bufferline.lua:7-9` work today by exactly this path.

**Bonus: it removes a hidden ordering dependency.** `handler/keys.lua:172-188` — when a plugin loads,
`M:_del` runs `pcall(vim.keymap.del, ...)` then `self:_set(keys, ...)`, re-creating the *real*
LazyVim mapping:

```lua
  for _, buf in ipairs(bufs) do
    pcall(vim.keymap.del, keys.mode, keys.lhs, { buffer = buf or nil })
    self:_set(keys, buf or nil)
  end
```

The current code's `<leader>bp` override survives only because `config.keymaps` runs *after*
bufferline loads (both on `User VeryLazy`; LazyVim fires `M.load("keymaps")` at
`config/init.lua:187-192`). The headless run confirms today's order. The fix makes the outcome
order-independent.

---

## Q3 — `vim.keymap.del` on `<leader>uz` / `<leader>uZ` (keymaps.lua:108-109) — **ISSUE** (fragility only)

LazyVim creates these via `/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/keymaps.lua:202-203`:

```lua
Snacks.toggle.zoom():map("<leader>wm"):map("<leader>uZ")
Snacks.toggle.zen():map("<leader>uz")
```

**Does `map()` also register with which-key? Yes.**
`/Users/zcu/.local/share/nvim/lazy/snacks.nvim/lua/snacks/toggle.lua:120-127`:

```lua
  self.opts.map(mode, keys, function()
    self:toggle()
  end, opts)
  if self.opts.which_key then
    Snacks.util.on_module("which-key", function()
      self:_wk(keys, mode)
    end)
  end
```

`toggle.lua:131-136`:

```lua
function Toggle:_wk(keys, mode)
  require("which-key").add({
    {
      keys,
      mode = mode,
      real = true,
```

**Does a stale entry remain after `vim.keymap.del`? NO.** `real = true` is defined as
`/Users/zcu/.local/share/nvim/lazy/which-key.nvim/lua/which-key/types.lua:58`:

```
---@field real? boolean this is a mapping for a real keymap. Hide it if the real keymap does not exist
```

and enforced at `/Users/zcu/.local/share/nvim/lazy/which-key.nvim/lua/which-key/tree.lua:62-69`:

```lua
  if node.mapping and node.mapping.real and not node.keymap then
    return false
  end
```

The check is against live `node.keymap` at render time, so the deleted key is filtered out of the
`<leader>u` popup. No ghost entry.

**The surviving issue is E31 fragility.** Per the headless run, `vim.keymap.del` on a missing mapping
throws `E31: No such mapping`, and LazyVim wraps the whole user module in `LazyVim.try`
(`config/init.lua:289-291`):

```lua
    if require("lazy.core.cache").find(mod)[1] then
      LazyVim.try(function()
        require(mod)
      end, { msg = "Failed loading " .. mod })
```

`try` notifies but does not rethrow — so a throw silently skips the remainder of the file. Blast
radius at 108-109 is small (they are the last two lines: a throw at 108 costs only 109), but the same
class at 53-54 would silently kill lines 55-109. Remedy differs from the Q2 fix: Snacks.toggle sets
these via `self.opts.map` (toggle.lua:120), *not* a lazy.nvim `keys` table, so a spec override cannot
remove them — `pcall(vim.keymap.del, ...)` is the correct shape.

**Counter-argument:** "LazyVim will not remove `Snacks.toggle.zen()`; this can't break." It already
depends on three moving parts outside the repo — the LazyVim keymaps file, snacks' toggle module, and
`vim.g.snacks_animate`-style config that could gate the toggle. And the cost of `pcall` is zero
characters of behavior change. Stands.

---

## Q4 — `<leader>cp` → `:LspStop` (keymaps.lua:106) — **ISSUE**

```lua
keymap.set("n", "<leader>cp", ":LspStop<Return>", { noremap = true, silent = true, desc = "Disable LSP" })
```

**Collision with the markdown extra is benign.** `/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/lang/markdown.lua:82-89` binds `<leader>cp` with `ft = "markdown"`.
`/Users/zcu/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/handler/keys.lua:151-163` turns `ft` keys
into buffer-local mappings via a `FileType` autocmd:

```lua
  if keys.ft then
    vim.api.nvim_create_autocmd("FileType", {
      pattern = keys.ft,
      callback = function(event)
        if self.active[keys.id] and not M.is_nop(keys) then
          add(event.buf)
```

Buffer-local mappings take precedence over global ones, so in markdown buffers `<leader>cp` is
Markdown Preview and elsewhere it is `:LspStop`. Silent shadowing, but not the defect.

**The defect is what `:LspStop` does.** The active branch is guarded by
`/Users/zcu/.local/share/nvim/lazy/nvim-lspconfig/plugin/lspconfig.lua:84` (`if vim.fn.has('nvim-0.11.2') == 1 then`)
— true on 0.11.4. Lines 170-194:

```lua
    -- Default to disabling all servers on current buffer
    if #client_names == 0 then
      client_names = vim
        .iter(vim.lsp.get_clients())
```

The comment says "current buffer"; `vim.lsp.get_clients()` is called with **no `bufnr` filter**, so it
returns every client in the session. The comment contradicts its own code. Then:

```lua
        vim.lsp.enable(name, false)
        if info.bang then
```

Without `!`, only `vim.lsp.enable(name, false)` runs.
`/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/lua/vim/lsp.lua:599`:

```lua
    lsp._enabled_configs[nm] = enable ~= false and {} or nil
```

and `lsp.lua:639-641`:

```lua
function lsp.is_enabled(name)
  return lsp._enabled_configs[name] ~= nil
end
```

The detach path `lsp_enable_callback` (`lsp.lua:526-532`) only detaches when
`lsp.is_enabled(client.name)` is true — which is now false. So **the currently attached client keeps
running and stays attached**; only future auto-attach is suppressed, globally, for every configured
server.

`desc = "Disable LSP"` is therefore inaccurate in both directions: it does not stop the running client
(that requires `:LspStop!`, lspconfig.lua:188-192), and it disables far more than "the LSP" — it
disables every server config in the session. Recovery is also partial: `:LspStart` with no args
(lspconfig.lua:113-121) re-enables only servers whose `filetypes` match the *current* buffer's
filetype, so running it from a different filetype does not restore the rest.

**Equivalents already available:** `vim.lsp.stop_client(client_id, force)`
(`runtime/lua/vim/lsp.lua:1116-1130`) for a targeted stop, and `:LspInfo` which is now an alias:
`lspconfig.lua:76` — `api.nvim_create_user_command('LspInfo', ':checkhealth vim.lsp', ...)`.

**Counter-argument:** "It's a panic button; over-broad is the point." Then the mapping should be
`:LspStop!` — the panic case is exactly the one where the misbehaving client is *already running* and
the no-bang form leaves it running. The desc is also wrong regardless of intent. Stands.

---

## Q5 — visual `p`/`P` swap (keymaps.lua:42-43) — **ISSUE** (mode scope, not intent)

```lua
keymap.set("v", "p", "P", opts)
keymap.set("v", "P", "p", opts)
```

**The intent is correctly achieved.** `change.txt:1154-1159`:

```
With |p| the previously selected text is put in the unnamed register (and
possibly the selection and/or clipboard).  This is useful if you want to put
that text somewhere else.  But you cannot repeat the same change.
With |P| the unnamed register is not changed (and neither the selection or
clipboard), you can repeat the same change. But the deleted text cannot be
```

`P` already does not stomp. The swap makes the *ergonomic* key (`p`) carry the non-stomping behavior,
which is exactly what the comment at :41 claims. With `clipboard=unnamedplus` (keymaps.lua:5), the
parenthetical "(and neither the selection or clipboard)" is the load-bearing clause: visual `p`
overwrites `+`/`*` too, visual `P` leaves them alone. Correct as written.

**The defect is `"v"`.** `map.txt:36-37` distinguishes the modes:

```
:vm[ap]	{lhs} {rhs}		|mapmode-v|		*:vm* *:vmap*
:xm[ap]	{lhs} {rhs}		|mapmode-x|		*:xm* *:xmap*
```

and `map.txt:420-426` states the rule directly:

```
						*mapmode-x* *mapmode-s*
Some commands work both in Visual and Select mode, some in only one.  Note
that quite often "Visual" is mentioned where both Visual and Select mode
apply. |Select-mode-mapping|
NOTE: Mapping a printable character in Select mode may confuse the user.  It's
better to explicitly use :xmap and :smap for printable characters.
```

`p`, `P` are printable. Select mode is where "typing text replaces the selection" (`map.txt:369`), so
in Select mode these maps hijack the keystroke instead of replacing the selection. Same defect at
`keymaps.lua:84` — `vim.keymap.set({ "n", "v" }, "q", "", { noremap = true })` makes `q` a no-op in
Select mode.

**Select mode is reachable in this stack.** Neovim's builtin snippet engine selects non-empty tabstops
in Select mode — `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/lua/vim/snippet.lua:319-326`:

```lua
    local keys = {
      mode ~= 'n' and '<Esc>' or '',
      ('<Cmd>call cursor(%s,%s)<CR>'):format(range[1] + 1, range[2] + 1),
      'v',
      ('<Cmd>call cursor(%s,%s)<CR>'):format(range[3] + 1, range[4]),
      'o<c-g><c-r>_',
    }
```

`<c-g>` switches Visual → Select. LazyVim's blink spec sets
`/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/coding/blink.lua:39-40`
(`snippets = { preset = "default" }`), i.e. the `vim.snippet` path, and the user's override does **not**
change it: `/Users/zcu/.config/nvim/lua/langs/blink.lua:3-5` nests `preset = "default"` under `keymap`,
not `snippets`, and the file contains no `snippets` key (grep for `snippets|preset|luasnip` matched only
`:5` and a comment at `:19`). Since `opts` deep-merges, LazyVim's `snippets.preset = "default"` survives.
The end-to-end trigger — typing a placeholder value beginning with `p` or `q` into an expanded snippet —
is one inference step from that config rather than a runtime observation; the Select-mode entry itself is
verified above. Note the ISSUE does not rest on the snippet path at all: `map.txt:424-426` is a
general prohibition, and Select mode is reachable directly via `gh`/`<C-g>` regardless.
Fix: use `"x"` for 42-43 and `{ "n", "x" }` for 84.

**Counter-argument:** "Nobody uses Select mode." It is not entered deliberately — `vim.snippet` puts
you there automatically on every non-empty tabstop, and `map.txt:424` calls this out as a known
confusion source precisely because it is invisible. The fix is a one-character change per line with no
downside. Stands.

---

## Q6 — `<leader>j` → ``*``cgn`` (keymaps.lua:89) — **NO ISSUE**

```lua
keymap.set("n", "<leader>j", "*``cgn", { noremap = true, silent = true })
```

`*` — `pattern.txt:61-73`:

```
							*star* *E348* *E349*
*			Search forward for the [count]'th occurrence of the
			word nearest to the cursor.  The word used for the
			search is the first of:
				1. the keyword under the cursor |'iskeyword'|
				2. the first keyword after the cursor, in the
				   current line
				3. the non-blank word under the cursor
				4. the first non-blank word after the cursor,
				   in the current line
			Only whole keywords are searched for, like with the
			command "/\<keyword\>".  |exclusive|
			'ignorecase' is used, 'smartcase' is not.
```

`` `` `` — `motion.txt:914-917`:

```
							*''* *``*
''  ``			To the position before the latest jump, or where the
			last "m'" or "m`" command was given.  Not set when the
			|:keepjumps| command modifier was used.
```

The wrap-around concern does not hold. The `` ` `` mark records the position *before* the jump, set at
the moment the jump command executes — it is independent of where the cursor lands. So when `*` wraps
and returns to the same position (single-match case), `` `` `` still restores the pre-`*` position,
which is the word itself. `cgn` then changes the match under/after the cursor. Correct in every case.

Caveat on the jump list: `motion.txt:1049-1050` enumerates jump commands as `"'", "`", "G", "/", "?",
"n", "N", "%", "(", ")", "[[", "]]", "{", "}", ":s", ":tag", "L", "M", "H"` — `*` is not listed by
name, but `pattern.txt:71-72` equates it to `/\<keyword\>`, and `/` is listed. (That equivalence is a
one-step inference from the two doc passages, not a separate verbatim statement.)

If `*` fails (`E348` "No string under cursor" / `E349`, tagged at `pattern.txt:61`), the mapping aborts
at `*` and `cgn` never runs — standard Vim mapping-abort behavior, not a defect.

**LazyVim does not bind `<leader>j`.** Grep for `leader>j|LspStop|autostart` across
`/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim` returned no matches. No collision.

**Minor, sub-issue level:** line 89 has no `desc`, so it is invisible in which-key. The repo's own
`docs/specs/customization-guide.md` says "Always include `desc` — it shows up in which-key." Every
other keymap in this file from line 50 onward carries one. Not counted as an ISSUE.

---

## Verdict on the proposed fix: **SOUND**

For its stated scope — replacing `keymaps.lua:53-66` with `keys` entries in
`lua/ui/bufferline.lua` — the fix is correct and strictly better than the code it replaces.

It reproduces the observed runtime state exactly (`<leader>bp` → `BufferLineMovePrev`, `<leader>bP` →
absent, `<leader>bn` → `BufferLineMoveNext`) through lazy.nvim's documented merge path: spec order
`lua/config/lazy.lua:20` before `:27` → fragment chaining `meta.lua:189-195` → list accumulation
`plugin.lua:451-465` with identity-only dedup `util.lua:338-349` → id dedup with later-wins and
`false`-removes `handler/keys.lua:80-87`. It eliminates two `vim.keymap.del` calls that throw `E31` on
a missing mapping, whose failure would be swallowed by `LazyVim.try` (`config/init.lua:289-291`) and
would silently skip lines 55-109 — grug-far `<leader>r`, the `S`/`q` disables, `<leader>j`, both yank-path
maps, `<leader>cp`, and the `uz`/`uZ` deletions. It also removes the implicit dependency on
`config.keymaps` running after bufferline's `VeryLazy` load, which is the only reason the current
override survives `handler/keys.lua:172-188` re-setting LazyVim's mapping at load time. `<Cmd>...<CR>`
is a strict improvement over `:...<Return>` (never enters command-line mode, per `map.txt:358-360`).

What it does not address, and should not be mistaken for addressing: `keymaps.lua:108-109` carry the
same E31 class and are outside the fix's scope. Their remedy is different in kind — Snacks.toggle
registers those through `self.opts.map` (`toggle.lua:120`), not a lazy.nvim `keys` table, so no spec
override can remove them; `pcall(vim.keymap.del, ...)` is the fitting shape there. Likewise
`<leader>ba` (Q1), `<leader>cp` (Q4), and the `"v"`-vs-`"x"` mode scope (Q5) are independent defects
the fix leaves untouched.

---

## Provenance

**Verified this session (files opened and read):**

- `/Users/zcu/.config/nvim/lua/config/keymaps.lua:1-109`
- `/Users/zcu/.config/nvim/lua/ui/bufferline.lua:1-27`
- `/Users/zcu/.config/nvim/lua/config/lazy.lua:1-58`
- `/Users/zcu/.config/nvim/lua/langs/luasnip.lua:1-11`
- `/Users/zcu/.config/nvim/lua/langs/blink.lua:1-12` (+ grep `snippets|preset|luasnip` over whole file)
- `/Users/zcu/.config/nvim/lua/ui/oil.lua` (grep `buf_options|buflisted` — no matches)
- `/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/ui.lua:1-60`
- `/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/keymaps.lua:36-51, 202-203`
- `/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/init.lua:174-200, 255-304, 324-340`
- `/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/lang/markdown.lua:75-93`
- `/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/coding/blink.lua:39-40, 87, 103`
- `/Users/zcu/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/handler/keys.lua:1-203`
- `/Users/zcu/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/handler/init.lua:1-140`
- `/Users/zcu/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/plugin.lua:420-483` (+ grep for `Spec:`/`setmetatable`)
- `/Users/zcu/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/meta.lua:10-29, 61-90, 166-261`
- `/Users/zcu/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/util.lua:338-349`
- `/Users/zcu/.local/share/nvim/lazy/snacks.nvim/lua/snacks/bufdelete.lua:1-125`
- `/Users/zcu/.local/share/nvim/lazy/snacks.nvim/lua/snacks/toggle.lua:10-63, 96-151, 249-251`
- `/Users/zcu/.local/share/nvim/lazy/which-key.nvim/lua/which-key/types.lua:54-62`
- `/Users/zcu/.local/share/nvim/lazy/which-key.nvim/lua/which-key/tree.lua:62-70`
- `/Users/zcu/.local/share/nvim/lazy/which-key.nvim/lua/which-key/mappings.lua:45-53`
- `/Users/zcu/.local/share/nvim/lazy/nvim-lspconfig/plugin/lspconfig.lua:1-45, 60-96, 97-204`
- `/Users/zcu/.local/share/nvim/lazy/oil.nvim/lua/oil/config.lua:15` (via grep)
- `/Users/zcu/.local/share/nvim/lazy/LuaSnip/lua/luasnip/util/select.lua:63` (via grep)
- `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/lua/vim/lsp.lua:518-543, 591-616, 639-641, 1116-1130`
- `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/lua/vim/snippet.lua:285-328`
- `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/doc/windows.txt:826-865, 1171-1193`
- `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/doc/options.txt:1164-1171, 1641-1651`
- `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/doc/editing.txt:1146-1262`
- `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/doc/change.txt:1142-1160`
- `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/doc/map.txt:30-42, 107-134, 358-370, 414-428`
- `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/doc/motion.txt:908-920, 1043-1055`
- `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/doc/pattern.txt:61-75`
- `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/doc/message.txt:425-437`

**Not verified this session (relied on, with reason):**

- LazyVim `options.lua:60` sets `confirm = true`, and the post-VeryLazy mapping state
  (`<leader>bp` = MovePrev, `<leader>bP` = nil, `<leader>bn` = MoveNext, `<leader>uz`/`<leader>uZ` = nil,
  `<leader>ba` = `:bufdo bd<CR>`), and `vim.keymap.del` throwing `E31` — supplied as VERIFIED FACTS
  from the main session's headless run. Not re-derived: the task forbids running nvim.
- Terminal-buffer `:bd` behavior under a running job — no runtime-doc source found; explicitly not asserted.
- The end-to-end "type `p` into a blink-expanded snippet placeholder" trigger in Q5 — the Select-mode
  entry (`snippet.lua:319-326`), LazyVim's `snippets.preset = "default"` (`extras/coding/blink.lua:39-40`),
  and the absence of a user override (`lua/langs/blink.lua`) are all read; the composition of the three
  into an observed keystroke is inference, labeled as such in Q5. The ISSUE itself does not depend on it.

**Gaps:** LuaSnip's own placeholder-jump mode was not resolved — four greps across
`/Users/zcu/.local/share/nvim/lazy/LuaSnip/lua/luasnip` for `gv|select_mode|enter_select|<C-g>` found
only `util/select.lua:63`, which is the `TM_SELECTED_TEXT` yank helper, not tabstop navigation. The Q5
conclusion does not depend on it: the `vim.snippet` path is verified and is what LazyVim's blink
`preset = "default"` selects.
