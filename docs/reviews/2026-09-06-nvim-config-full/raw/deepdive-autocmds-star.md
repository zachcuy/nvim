---
title: Deep-dive - C/C++ block-comment autocmd in lua/config/autocmds.lua
created: 2026-09-06
updated: 2026-09-06
status: final
topics:
  - autocmds
  - keymaps
  - insert-mode
  - mini-pairs
  - dot-repeat
---

# Deep-dive: `*` insert mapping (autocmds.lua:19-34)

Verdict: **4 ISSUE, 2 NO ISSUE**

---

## Q1 — `nvim_replace_termcodes(..., true, false, true)` — NO ISSUE

`/Users/zcu/.config/nvim/lua/config/autocmds.lua:23`

Signature (`doc/api.txt:1274-1285`):

```
nvim_replace_termcodes({str}, {from_part}, {do_lt}, {special})
  • {from_part}  Legacy Vim parameter. Usually true.
  • {do_lt}      Also translate <lt>. Ignored if `special` is false.
  • {special}    Replace |keycodes|, e.g. <CR> becomes a "\r" char.
```

Order is correct: `from_part=true`, `do_lt=false`, `special=true`. `special=true` is what converts `<Left>`. `do_lt` only governs the literal `<lt>` keycode; the string contains none, so `false` changes nothing. This is verbatim the documented idiom (`doc/api.txt:726`): `nvim_replace_termcodes("<C-o>", v:true, v:false, v:true)`. Pairing it with `escape_ks=false` is also correct per `doc/api.txt:736-738`.

---

## Q2 — `nvim_feedkeys(keys, "n", false)` without `i` — ISSUE

`/Users/zcu/.config/nvim/lua/config/autocmds.lua:28,30`

`doc/vimfn.txt:2204-2208`:

```
By default the string is added to the end of the typeahead
buffer, thus if a mapping is still being executed the
characters come after them.  Use the 'i' flag to insert before
other characters, they will be executed next, before any
characters from a mapping.
```

Keys already typed do sit in typeahead — `doc/map.txt:203-204`: "However, if the characters were already typed they are used."

Concrete failure, `/*x` in one burst: `/` inserts; `*` fires the mapping; guard reads the buffer *now*, sees `/`, passes; `close` is appended **after** the pending `x`. Processing order is `x`, then `*  */<Left><Left><Left>`. Result: `/x*  */` with the cursor between the two spaces. The intended `/*  */` never exists.

Worse, the else branch (`:30`) has the same defect for every plain `*`. `int *p` typed in a burst transposes to `int p*` — and C/C++ is pointer-dense, so this is not a corner case.

**Counter-argument:** "terminals deliver one key per read, so typeahead is empty." It usually is — but LSP/treesitter reparse and GC stalls batch keystrokes routinely, and the failure is silent buffer corruption. The fix (`{ expr = true }`, returning the string) is what mini.pairs itself does (`mini/pairs.lua:193`: `{ expr = true, noremap = true }`) and has no downside. Stands.

---

## Q3 — guard only checks the byte before the cursor — ISSUE

`/Users/zcu/.config/nvim/lua/config/autocmds.lua:27`: `if line:sub(col - 1, col - 1) == "/" then`

Wrong firings:

| Context | Typed | Corrupted result |
|-|-|-|
| Doxygen comment | `/**` | `/* * */` (wanted `/**  */`) |
| String glob | `"src/*.c"` | `"src/*  */.c"` |
| Inside open block comment | `/* see a/*.c */` | nested `/*  */` garbage |
| `//` comment w/ URL | `// http://x/*` | `// http://x/*  */` |
| Char/string path in macro | `#define P "a/*"` | same as string case |

Not a wrong firing: `a /*p` (division then dereference). C lexes `/*` as comment start by maximal munch, so the user must write `a / *p`; the byte before `*` is then a space and the guard does not fire. Firing on `a/*p` is *correct*.

Cheap guard — mirror LazyVim, which already does exactly this for autopairs (`lazyvim/util/mini.lua:113`):

```lua
local ok, captures = pcall(vim.treesitter.get_captures_at_pos, 0, cursor[1] - 1, math.max(cursor[2] - 1, 0))
```

`vim.treesitter.get_captures_at_pos({bufnr}, {row}, {col})` exists in 0.11.4 (`doc/treesitter.txt:945`); `vim.treesitter.get_captures_at_cursor({winnr})` also exists (`doc/treesitter.txt:934`) but at insert-mode end-of-line it queries past the last character — use the before-cursor column form.

Caveat: **treesitter cannot fix the Doxygen `/**` case.** When the first `*` is typed the tree has no comment node yet, so no capture check helps. Only strings and already-open comments are recoverable this way. `vim.fn.synID()` exists (`doc/vimfn.txt:10833`) but reflects regex `'syntax'` only; with treesitter highlighting active for c/cpp it commonly returns 0 — verify it is populated before relying on it.

**Counter-argument:** the author's guard is one line and covers the 90% case. But the failures are silent text corruption in ordinary code (glob strings, Doxygen), not exotic input. Stands.

---

## Q4 — mini.pairs interaction — NO ISSUE

mini.pairs defaults (`mini/pairs.lua:149-161`) map only `(`, `[`, `{`, `)`, `]`, `}`, `"`, `'`, `` ` `` — plus `<BS>`/`<CR>` (`mini/pairs.lua:554-558`). No `*`, no `/`. LazyVim's opts (`lazyvim/plugins/coding.lua:8-19`) add `skip_next`, `skip_ts`, `skip_unbalanced`, `markdown`; the markdown fence branch (`lazyvim/util/mini.lua:106`) is gated on `` o == "`" `` and `filetype == "markdown"`, so it never sees c/cpp.

Even if it did: `doc/map.txt:188` — "The local buffer mappings are used before the global ones." — and `"n"` on feedkeys blocks remapping.

Non-correctness note: because `/*`/`*/` is not registered via `MiniPairs.map`, mini.pairs' `<BS>` will not delete the pair as a unit. UX only.

---

## Q5 — dot-repeat — ISSUE

`/Users/zcu/.config/nvim/lua/config/autocmds.lua:23` uses bare `<Left>`.

`doc/insert.txt:342-344` (arrow keys are `ins-special-special`):

```
The changes (inserted or deleted characters) before and after these keys can
be undone separately.  Only the last change can be redone and always behaves
like an "i" command.
```

So for `i` + `/*` + comment text + `<Esc>`: the three `<Left>`s split the insert. `.` replays only the last change (the comment text), not `/*  */`; `u` needs two presses. mini.pairs hit this and documents it at `mini/pairs.lua:421-427`:

```
  -- Using left/right keys in insert mode breaks undo sequence and, more
  -- importantly, dot-repeat. To avoid this, use 'i_CTRL-G_U' mapping.
  left_undo  = escape('<C-g>U<Left>'),
```

Fix: `<C-g>U<Left>` (`doc/insert.txt:382-384`, example at `:432`: `inoremap ( ()<C-G>U<Left>`).

Scope limits stated honestly: (a) `doc/repeat.txt` documents nothing about insert-mode `.` — grepped for `redo|Insert mode`, only hits are `:27` and `:93`, both unrelated; the governing text is `insert.txt`. (b) whether redo replays recorded characters vs. the mapping lhs is not covered by any quote I found, so I make no claim there. (c) for the degenerate `i/*<Esc>` with nothing typed after the `<Left>`s, the exact `.` output depends on redo-buffer internals I cannot verify without running nvim.

**Counter-argument:** a user may never press `.` after opening a comment. But `u` behaving inconsistently is noticed immediately, and the fix is a 6-character edit that the config's own autopair plugin already applies. Stands.

---

## Q6 — no augroup — ISSUE (low severity)

`/Users/zcu/.config/nvim/lua/config/autocmds.lua:10` and `:20` both omit `group`.

Three separate answers:

- **Duplicated mapping? No.** Re-running `vim.keymap.set` for the same mode/lhs/buffer replaces silently. `doc/map.txt:238-241`: `<unique>` exists precisely because "the command will fail if the mapping or abbreviation already exists" is *opt-in*. So `:e!` and filetype re-detection are idempotent.
- **Leak? Yes.** `doc/map.txt:194-195`: "Local mappings are also cleared when a buffer is deleted, but not when it is unloaded." `:set ft=lua` on a former cpp buffer leaves the `*` mapping live, still feeding `*  */` after a `/`.
- **Autocmd duplication? On re-source only** (`:so %` during config editing). Without a group the copies are also undeletable — directly contradicting this file's own header at `:7-8` ("remove existing autocmds by their group name").

LazyVim does the opposite (`lazyvim/config/autocmds.lua:3-5`):

```lua
local function augroup(name)
  return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = true })
end
```

`{ clear = true }` makes re-sourcing idempotent, and every LazyVim autocmd passes `group = augroup(...)`.

Markdown autocmd (`:10-17`) has the same gap, plus a latent ordering dependency: it sets `wrap = false` / `spell = false` while LazyVim's `wrap_spell` group (`lazyvim/config/autocmds.lua:103-110`) sets both `true` for `markdown`/`text`. It wins only because the user's file registers later, not by design.

**Counter-argument:** LazyVim loads `autocmds.lua` exactly once, so re-source duplication is a dev-loop concern and a senior engineer could call it hygiene. That half is fair — but the filetype-change mapping leak is a real behavioral bug independent of sourcing. Stands at low severity.

---

## Files Read

- `/Users/zcu/.config/nvim/lua/config/autocmds.lua:1-35`
- `/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/autocmds.lua:1-132`
- `/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/coding.lua:1-40`
- `/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim/util/mini.lua:82-131`
- `/Users/zcu/.local/share/nvim/lazy/mini.pairs/lua/mini/pairs.lua:137-162, 190-235, 408-432, 612-627`
- `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/doc/api.txt:710-754, 1270-1294`
- `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/doc/vimfn.txt:2200-2261, 10833, 10867`
- `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/doc/insert.txt:330-444`
- `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/doc/map.txt:181-249`
- `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/doc/treesitter.txt:930-961`
- `/Users/zcu/.local/share/bob/v0.11.4/share/nvim/runtime/doc/repeat.txt` (grepped `redo|Insert mode`; no insert-mode redo docs)

## Gaps

- Exact `.` output for the degenerate `i/*<Esc>` (no text after the `<Left>`s) depends on redo-buffer reset internals not covered by the runtime docs; resolving it requires running nvim, which was out of scope. Q5's ISSUE does not rest on it.
- Whether Neovim's redo buffer stores inserted characters or the mapping lhs is not documented in `insert.txt`, `map.txt`, or `repeat.txt` (all grepped). No claim made.
