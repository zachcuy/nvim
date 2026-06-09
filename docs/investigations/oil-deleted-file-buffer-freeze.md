---
title: Oil.nvim deleted-file buffer freeze — investigation and fix
created: 2026-06-09
updated: 2026-06-09
status: final
topics:
  - oil-nvim
  - buffers
  - performance
---

# Oil.nvim deleted-file buffer freeze

## Symptom

Open a file → open oil with `<leader>e` → delete that file in oil → save the oil buffer
(this performs the trash) → close oil. The editor becomes unresponsive for "a long time"
before recovering. User's description: "it tries to load the buffer of the file that I just
deleted which it can no longer find."

## Root cause (one sentence)

Oil does not remove a file's Neovim buffer when it deletes the file, so closing oil parks the
window back on that now-fileless buffer, and Neovim core's interactive deleted-file handling
(`E211`) blocks the UI for about a second every time it is triggered.

It is two independent issues stacked: an oil gap that **creates** the stale buffer, and a
Neovim-core cost that **punishes** displaying it.

## The causal chain

1. **Oil leaves the buffer behind on delete.** `cache.perform_action` for a `delete` only
   scrubs oil's internal cache tables — it never touches the Neovim buffer (`cache.lua:158-166`).
   The `move` branch does update buffers (`cache.lua:190` → `util.update_moved_buffers`), but
   `delete_to_trash` stays a `delete` action (performed by routing to the trash adapter inside
   the delete branch, `files.lua:605-624`) — so the move/rename buffer path never runs for it.
2. **Closing oil restores the stale buffer.** `:Oil` opens in-window (`keymaps.lua:45-47`), so
   `oil.close` takes the non-float path and calls `nvim_win_set_buf(0, oil_original_buffer)`
   (`init.lua:418-424`). That puts the window back on the deleted file's buffer.
3. **Displaying it triggers `E211`.** Neovim detects the missing file and fires
   `FileChangedShell` with `reason=deleted`; it does **not** reload (no `BufReadPost`), so the
   buffer keeps its in-memory content.
4. **The interactive handling freezes the UI ~1s per trigger.** This is Neovim core behavior in
   the UI redraw path — it does not occur headless, and it reproduces under bare `nvim --clean`.

## Verified facts (read or measured this session)

| Fact | Evidence |
|-|-|
| Delete only updates oil cache, not the buffer | `cache.lua:158-166` (read) |
| Move updates buffers; delete does not | `cache.lua:190` (read) |
| `delete_to_trash` stays a `delete` action; path via `parse_url`+`posix_to_os_path` | `files.lua:605-624` (read) |
| `oil.close` restores `oil_original_buffer` via `nvim_win_set_buf`; else `bprev`/`enew` | `init.lua:418-440` (read) |
| `<leader>e` runs `:Oil` (in-window open) | `keymaps.lua:45-47` (read) |
| macOS trash is async libuv rename to `~/.Trash` (no Finder/`osascript`) | `adapters/trash/mac.lua:203-230` (read) |
| LazyVim `checktime` only on `FocusGained`/`TermClose`/`TermLeave` (not buffer-enter) | LazyVim `config/autocmds.lua` (read) |
| `OilActionsPost` fires in `finish()` after actions complete, `data={err,actions}` | `mutator/init.lua:418-428` (read) |
| `parse_url` at `util.lua:16-18`; `posix_to_os_path` at `fs.lua:86` | grep + read (`parse_url` body read) |
| `autoread=true`, `updatetime=50`, `swapfile=false` | `options.lua:114,111,81` (read) |
| Returning to a deleted-file buffer fires `FileChangedShell reason=deleted`, **no** `BufReadPost` | bare-nvim experiment |
| Headless: `oil.close` 0.53 ms, event-loop max gap 51.8 ms (no block), no error | headless full-flow experiment |
| Interactive freeze ~1.0–1.2 s, deleted-specific, **not** LSP/filetype/prompt | A/B/C/D PTY experiment |
| Freeze reproduces under bare `nvim --clean` (1.04 s vs 0.10 s control) → Neovim **core** | bare-clean PTY experiment |

### Controlled comparison (PTY, freeze when returning to the buffer)

| Scenario | Freeze | `E211` |
|-|-|-|
| `.lua`, file present (control) | 0.09 s | no |
| `.lua` deleted (lua_ls attached) | 1.19 s | yes |
| `.txt` deleted (no LSP) | 1.16 s | yes |
| `.txt`, file present (control) | 0.09 s | no |
| bare `nvim --clean`, deleted | 1.04 s | yes |
| bare `nvim --clean`, control | 0.10 s | no |

## Unverified claims (leads, not facts)

| Claim | Priority | Why unverified |
|-|-|-|
| Exact Neovim C function/line for the ~1s interactive cost (`buf_check_timestamp` + redraw) | Low | Lives in Neovim's C source, outside this repo; characterized empirically but not line-pinned. Not load-bearing for the fix. |
| "Long time" (worse than ~1s) comes from repeated re-triggering via `autoread`+`updatetime=50`+focus `checktime` while parked on the buffer | Low–Med | Reasoned from settings; the per-trigger ~1s is measured, the compounding loop is not directly measured. |
| Deleting a directory leaves child file buffers stale | Low | Inferred from the path-matching logic; not empirically tested. |

## What worked

- Reading oil source in execution order: `cache.perform_action` → files adapter delete →
  `mac.lua` trash → `oil.close`. This exposed exactly where the buffer is (not) handled.
- A **headless** reproduction with an event-loop block detector (a repeating 50 ms libuv timer;
  late fires would reveal a synchronous freeze). It proved there is **no** code-level block —
  redirecting the hunt to interactive-only causes.
- A **PTY-driven interactive** reproduction (`pty.fork` + a fixed 80x24 winsize) that performed
  the exact `nvim_win_set_buf` oil does, then probed responsiveness. This caught the real freeze.
- A controlled **A/B/C/D** matrix that varied one factor at a time (filetype, LSP presence,
  deleted-vs-present) to isolate the cause to the deleted-file state alone.
- Bare `nvim --clean` in a PTY to localize the cost to Neovim **core** vs the user's config.
- Confirming the fix hook empirically: a probe `OilActionsPost` autocmd printed the action types,
  proving the action is `delete` (not a move-to-trash) — so a delete-only handler is correct.

## What didn't work / dead ends

- **vim-sleuth's `BufReadPost` directory scan** (initial top hypothesis). Dead: returning to the
  buffer does **not** reload, so `BufReadPost` never fires (proven by the bare-nvim event log).
- **"macOS trash is slow (Finder/osascript)."** Dead: `mac.lua:203-230` is async libuv rename.
- **Blocking `W11`/`[O]K, (L)oad File:`/hit-enter prompt.** Dead: the PTY screen showed none of
  those markers, and the editor recovered on its own (both follow-up commands ran).
- **LSP / gitsigns synchronous work on `BufEnter`.** Dead: grep found no heavy buffer-enter
  handler, and A/B/C showed the freeze is identical with and without LSP.
- **`nvim -l script.lua` to run with the real config.** Dead: `-l` is bare Lua mode and skips the
  user config — `require('oil')` is not found. Use `nvim --headless -c "luafile ..."` instead.
- **`timeout` command** is absent on macOS. Used `perl -e 'alarm shift; exec @ARGV' <secs> ...`.
- **Headless alone** could not reveal the freeze (0.5 ms) because it is interactive/UI-only; the
  PTY harness was required.

## What ultimately worked

The combination, not any single tool: headless proved it is **not** a code block; PTY proved it
**is** a real interactive freeze; A/B/C/D + bare-`--clean` localized it to Neovim **core**
deleted-file handling. Root cause = stale buffer (`cache.lua:158-166`) + `oil.close` restoring it
(`init.lua:420`) + core `E211` handling freezing the UI.

## The fix

A `User`/`OilActionsPost` autocmd in `lua/ui/oil.lua` (added after `oil.setup()`, the
`OilActionsPost` block). On each completed `delete` action it resolves the URL exactly as oil
does (`oil.util.parse_url` → `oil.fs.posix_to_os_path`), canonicalizes through the still-present
parent directory (so `/var` vs `/private/var` symlinks match), and wipes any loaded, **unmodified**
buffer whose name matches. With the stale buffer gone, `oil.close`'s `nvim_buf_is_valid` check
(`init.lua:419`) fails and it falls through to `bprev`/`enew` — Neovim never parks on the deleted
file, so the `E211` freeze never fires.

Design choices:
- **Skip modified buffers** (`not vim.bo[bufnr].modified`): never silently discard unsaved work.
  Trade-off: the rare modified-buffer case still freezes.
- **`pcall` around `nvim_buf_delete`**: a failure must not break oil's mutation flow.
- **Delete-only, exact-path match**: surgical to the reported single-file case. Directory deletes
  do not wipe child file buffers (the action path is the directory).

### Fix verification

| Check | Before | After |
|-|-|-|
| Close freeze (PTY, real oil flow) | 1.0–1.2 s | 0.09 s |
| `E211` triggered | yes | no |
| File's buffer after trash (headless) | survives | wiped |
| `oil.close` target buffer | stale (deleted) | fresh buffer |
| Editor responsive after close | — | yes |

## Reproduction / verification recipe (for next time)

- Headless mechanism check: open a temp file, `require('oil').open(dir)`, delete the file's line
  with `nvim_buf_set_lines`, `require('oil').save({confirm=false}, cb)`, `vim.wait` for `cb`,
  then assert the file's bufnr is no longer valid and `oil.close()` lands elsewhere. Run with
  `nvim --headless -c "luafile <script>"`.
- Interactive freeze check: `pty.fork()` an `nvim <file>` (set winsize 80x24), drive the same flow
  via `:lua` commands, and time from sending `require('oil').close()` until the screen goes quiet;
  grep the cleaned PTY output for `E211`. Pre-fix ≈ 1 s + `E211`; post-fix ≈ 0.1 s, no `E211`.
- Localize core-vs-config by repeating the buffer switch under `nvim --clean`.

## Approach for next session

1. Root cause **resolved**; fix **implemented and verified** in `lua/ui/oil.lua`.
2. If the freeze recurs: confirm oil still emits `OilActionsPost` (event name unchanged across oil
   versions), and re-run the PTY verification to confirm `canonical_path` still matches the real
   buffer name.
3. Optional extensions if requested: (a) handle directory deletes by wiping buffers whose path is
   under the deleted directory; (b) handle modified buffers (unlist or wipe with confirmation).
4. The exact Neovim-core mechanism for the ~1s is not pinned; only relevant if an upstream change
   makes the freeze reappear without a stale buffer being involved.

## Key files quick reference

| File | Role |
|-|-|
| `lua/ui/oil.lua` | Oil config; the `OilActionsPost` cleanup autocmd (the fix) lives here |
| `lua/config/keymaps.lua:45-47` | `<leader>e`/`<leader>o` → `:Oil` (in-window open) |
| `lua/config/options.lua:81,111,114` | `swapfile=false`, `updatetime=50`, `autoread=true` |
| oil `cache.lua:158-166,190` | delete (no buffer touch) vs move (updates buffers) |
| oil `adapters/files.lua:605-624` | delete branch; `delete_to_trash` routing + path conversion |
| oil `adapters/trash/mac.lua:203-230` | async libuv trash (rename to `~/.Trash`) |
| oil `init.lua:407-441` | `oil.close` buffer-restore logic |
| oil `mutator/init.lua:418-428` | `OilActionsPost` emission (the fix hook) |
| oil `util.lua:16-18`, `fs.lua:86` | `parse_url`, `posix_to_os_path` |

## Decisions made

| Decision | Rationale |
|-|-|
| Fix at the oil layer (wipe buffer on delete), not the close layer | Attacks the root cause (the stale buffer) instead of the symptom; uses oil's public `OilActionsPost` event |
| Hook `OilActionsPost`, match `delete` actions only | Empirically confirmed the action is `delete` (not move-to-trash); fires after the trash completes |
| Skip modified buffers | Never discard unsaved work; accepts a rare residual freeze for that case |
| Canonicalize via the parent dir's realpath | The deleted file can't be realpath'd; the parent still exists, so `/var` vs `/private/var` symlinks resolve consistently |
| Keep it delete-only and single-file | Surgical to the reported bug; directory-recursive cleanup deferred unless requested |
| Place the autocmd in `lua/ui/oil.lua` | Cohesive with the oil spec; oil loads eagerly so the autocmd registers once at startup |
