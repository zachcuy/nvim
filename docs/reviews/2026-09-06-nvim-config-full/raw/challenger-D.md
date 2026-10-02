---
title: Cross-review challenger D verdicts (M11, M12, M15, M16)
created: 2026-09-06
updated: 2026-09-06
status: final
topics:
  - code-review
  - nvim-config
---

Acronyms used: OSC (Operating System Command), SSH (Secure Shell), CSI u (Control Sequence Introducer "u" key encoding), TUI (Terminal User Interface).

## M11: DOWNGRADED to LOW
Original: checkmate `cancelled.order = 2` ties with built-in `checked.order = 2`, making cycle order arbitrary.
Verdict: DOWNGRADED to LOW

### Evidence
`~/.local/share/nvim/lazy/checkmate.nvim/lua/checkmate/config/defaults.lua:98-102`:
```lua
    ---@diagnostic disable-next-line: missing-fields
    checked = {
      marker = "✔",
      order = 2,
    },
```
`lua/misc/checkmate.lua:81-86` sets `cancelled = { ..., order = 2 }`; `on_hold` = 100.
`parser/init.lua:207-220`: `for name, def in pairs(config.options.todo_states)` … `table.sort(states, function(a, b) return a.order < b.order end)`.
`parser/init.lua:193-195,222`: `if todo_states_cache then return todo_states_cache end` … `todo_states_cache = states`.
`config/init.lua:570-571`: `prevent_merge(opts)` (clears only `keys`, `list_continuation.keys`, `metadata`) then `vim.tbl_deep_extend("force", config, opts)` — `todo_states` merges, defaults survive.
`config/validate.lua:178-179`: only `type(def.order) ~= "number"` is checked — no duplicate-order check.

### Reasoning
The tie is real: both `checked` and `cancelled` end at order 2, and the sort's tie-break falls to `pairs()` enumeration order plus LuaJIT's unstable quicksort — not to the user's `order`. Within a session the result is fixed (module-level `todo_states_cache`); whether it varies across sessions I could not verify (no LuaJIT source on disk, no shell available), so the "non-deterministic across sessions" wording is unproven. Impact is bounded: the sole consumer is `api.lua:1042` (`get_next_todo_state`, used by `<leader>t=`/`<leader>t-`); all four states remain reachable, only the relative position of `checked` vs `cancelled` is arbitrary, so one `<leader>t=` from unchecked may write `- [c]` instead of `- [x]` — immediately visible and reversible. Direct commands (`<leader>tt`, `tc`, `tu`, `tx`, `th`) bypass the ordered list entirely.

### Fix Assessment
Correct. `order = 3` is free: the only orders in play are 1 (unchecked), 2 (checked), 100 (on_hold). No interaction with the `max_order + 1` fallback at parser/init.lua:211-215 since all four states declare `order`. `a.order < b.order` stays a valid strict weak ordering either way, so there is no "invalid order function" risk in either state.

Counter-argument: if LuaJIT's short-string hashing is seeded per process, the cycle order really would flip between sessions, which feels like MEDIUM. It still stands as LOW because even then the blast radius is one keystroke producing the wrong checkbox character in a markdown file — no data loss, no error, instantly undoable, and the same two keys reach the intended state on the next press.

## M12: CONFIRMED (severity LOW)
Original: `guicursor` uses `o:` (operator-pending) where the comment says command mode; `VisualCursor` is defined but never used.
Verdict: CONFIRMED (claim true; severity should be LOW, not MEDIUM)

### Evidence
`runtime/doc/options.txt:3027-3032`:
```
		o	Operator-pending mode
		i	Insert mode
		r	Replace mode
		c	Command-line Normal (append) mode
		ci	Command-line Insert mode
		cr	Command-line Replace mode
```
`lua/config/options.lua:37-38`: `-- Command mode` … `"o:block-CommandCursor/lCursor-blinkwait700-blinkon400-blinkoff250",`
`lua/config/options.lua:23`: `vim.api.nvim_set_hl(0, "VisualCursor", ...)` — grep of all `*.lua` under `/Users/zcu/.config/nvim` returns this definition and no other `VisualCursor` reference; `v` is on :29 under `NormalCursor`.

### Reasoning
The mode letters confirm the mislabel: the "Command mode" comment sits over a spec whose mode-list contains no command-line letter at all, so operator-pending (after `d`/`c`/`y`) gets the blinking spec. `VisualCursor` is genuinely dead. Two corrections to the finding as written: (1) the "only visible once H1 is fixed" caveat is wrong for blinking — blink arguments are independent of the highlight group, so operator-pending blinks and `c` does not *today*, even with the groups cleared by `hi clear` (lume/init.lua:18; syntax.txt:4880-4881 "Removes all highlighting for groups added by the user"); (2) `ci` (:32) and `cr` (:35) already get the yellow blinking spec, so `c` is the only command-line letter left on `NormalCursor` — which of `c`/`ci` Nvim picks while typing at the command line is C-source behavior I cannot read here. Everything is cosmetic; no functional effect.

### Fix Assessment
The proposed `"c-ci-cr:block-CommandCursor/lCursor-blink..."` works but duplicates `ci` (:32) and `cr` (:35); harmless only because `InsertCursor`, `ReplaceCursor`, `CommandCursor` and `VisualCursor` are all `fg=#1e1e2e, bg=#ffd400` (:22-25). Minimal fix: change `o` to `c` on :38 and drop `c` from :29. Note the side effect: with `o` unlisted, operator-pending falls back to `block` with no blink — options.txt:3041 "Default is "block" for each mode." and :3052 "Default is "blinkon0" for each mode." Not a bug. `sm` grouped with `n-v-c` and `ve` grouped with insert both match the shipped default (options.txt:3006), so neither is a deviation. Deleting `VisualCursor` (:23) is safe.

Counter-argument: one could call the mislabel harmless since all four yellow groups are identical, so the only real symptom is a blinking cursor during operator-pending. That is exactly why the severity drops to LOW — but the finding still stands, because the config's stated intent (CLAUDE.md:33, "yellow blinking in insert/replace/command") is not what the option expresses.

## M15: DOWNGRADED to LOW
Original: mapping `<Tab>` in normal mode removes jumplist-forward (`<C-i>`).
Verdict: DOWNGRADED to LOW (fact fully confirmed; classification is a documented trade-off, and the real defect is docs drift)

### Evidence
`runtime/doc/motion.txt:1057-1065`:
```
<Tab>		or					*CTRL-I* *<Tab>*
CTRL-I			Go to [count] newer cursor position in jump list
			NOTE: In the GUI and in a terminal supporting
			|tui-modifyOtherKeys| or |tui-csiu|, CTRL-I can be
			mapped separately from <Tab>, on the condition that
			both keys are mapped, otherwise the mapping applies to
			both. Except in tmux: https://github.com/tmux/tmux/issues/2705
```
`lua/ui/bufferline.lua:7`: `{ "<Tab>", "<Cmd>BufferLineCycleNext<CR>", desc = "Next Buffer" }` (no `mode` → normal).
`lua/search/fzf.lua:30`: `-- On macOS the Option key sends Alt, which tmux grabs before fzf sees it.` — the user runs tmux.
Grep for `C-i` across `/Users/zcu/.config/nvim/lua` returns no match; the only `<Tab>` hits are bufferline.lua:7-8 and blink.lua:22-23 (insert-mode completion fallback).

### Reasoning
The mechanism is confirmed by the runtime doc, not inferred: because only `<Tab>` is mapped and `<C-i>` is not, the mapping applies to both regardless of terminal capability. The escape hatch (map both keys, use a CSI u / modifyOtherKeys terminal) is closed for this user by tmux, per the doc's own exception plus fzf.lua:30. Nothing in the config restores jump-forward. But this is the direct, deliberate consequence of a choice recorded in CLAUDE.md's override table, `<C-o>` still walks the jumplist backward, and `:jumps` remains available — a lost convenience key, not a correctness or data problem.

### Fix Assessment
No code fix is warranted. Two options, both costly: (a) map an alternative to `<C-i>`'s function (e.g. `vim.keymap.set("n", "<leader>i", "<C-i>")`) — works under tmux, adds a key; (b) map both `<Tab>` and `<C-i>` — per motion.txt:1065 this does not help under tmux, so it would silently not work for this user. The actionable item is documentation: CLAUDE.md's override table lists the `<Tab>` cost as "Indent/snippet navigation" and omits jumplist-forward, so the user made the choice without the full price written down.

Counter-argument: losing `<C-i>` is a daily annoyance for jumplist users, which argues for MEDIUM. It stays LOW because severity here should track "is this a defect", and a knowingly-remapped key with a preserved inverse (`<C-o>`) and a doc entry is a trade-off; the only unrecorded part is the docs gap, which is itself a LOW/nit.

## M16: DISMISSED
Original: `vim.opt.clipboard = "unnamedplus"` in keymaps.lua discards LazyVim's SSH-aware default.
Verdict: DISMISSED

### Evidence
LazyVim `lua/lazyvim/config/init.lua:339-341` (inside `M.init`, before any plugin loads):
```lua
  -- defer built-in clipboard handling: "xsel" and "pbcopy" can be slow
  lazy_clipboard = vim.opt.clipboard:get()
  vim.opt.clipboard = ""
```
LazyVim `lua/lazyvim/config/init.lua:192-195` (VeryLazy callback):
```lua
      M.load("keymaps")
      if lazy_clipboard ~= nil then
        vim.opt.clipboard = lazy_clipboard
      end
```
LazyVim `lua/lazyvim/config/init.lua:296-300`: `_load("lazyvim.config." .. name)` … `_load("config." .. name)` — the user's `config.keymaps` is required synchronously inside `M.load("keymaps")`, i.e. before :194 runs.
LazyVim `lua/lazyvim/config/options.lua:57`: `opt.clipboard = vim.env.SSH_CONNECTION and "" or "unnamedplus"`.

### Reasoning
The claimed mechanism is refuted by an ordering guard the finding did not account for. `M.init` captures the SSH-aware value at startup (`lazy_clipboard`), blanks the option, and the VeryLazy callback restores `lazy_clipboard` *after* the user's keymaps.lua has run. So over SSH the final value is `""`, not `"unnamedplus"`, and OSC 52 auto-selection stays reachable — `autoload/provider/clipboard.vim:260-263` gates it on `get(get(g:, 'termfeatures', {}), 'osc52') && &clipboard ==# ''`. The user's line 5 is inert: a grep for `clipboard` across `/Users/zcu/.config/nvim/lua` finds only keymaps.lua:5 and an unrelated comment at oil.lua:118, so nothing re-sets it after :194, and no clipboard operation can occur inside the microsecond window between :192 and :194. The observed `clipboard = "unnamedplus"` in runtime-facts:22 is consistent with this: the machine is not SSH, so `lazy_clipboard` was `unnamedplus` anyway.

### Fix Assessment
N/A for the SSH claim. A NIT remains: keymaps.lua:5 is a dead assignment in the wrong file (CLAUDE.md designates options.lua for options); deleting it changes nothing at runtime. Warning about the proposed alternative "move it to options.lua": that WOULD break the SSH case, because :340 captures whatever `M.load("options")` leaves — the user's options.lua is loaded at :300 *after* LazyVim's, so an unconditional `unnamedplus` there would be captured into `lazy_clipboard` and restored at :194. The safe fix is deletion only. On `<C-c>` → `"+y` (keymaps.lua:6): redundant only while `unnamedplus` is active (options.txt:1395-1398 — `unnamedplus` routes "all yank, delete, change and put operations" to `+`); over SSH with `clipboard=""` it is the explicit path to the OSC 52 provider, so it is not dead code everywhere.

Counter-argument: if the user ever removes LazyVim, or LazyVim drops the deferred-clipboard trick, keymaps.lua:5 becomes live and the SSH problem appears for real. That is a hypothetical about a different codebase state; against the code as it exists at LazyVim commit c10948c5, the finding's mechanism does not fire, so it is a false positive today and should be reported as a nit at most.
