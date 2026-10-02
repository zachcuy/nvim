---
title: Checkmate @done date increment/decrement keymap
created: 2026-10-02
updated: 2026-10-02
status: final
topics:
  - checkmate
  - keymaps
---

# Checkmate @done date increment/decrement keymap

Goal: a hotkey that shifts the `@done(mm/dd/yy)` value on the todo under the cursor by one day, with month and year rollover.

## Verified Facts

Plugin source: `~/.local/share/nvim/lazy/checkmate.nvim` at commit `e57c8b5` (from `lazy-lock.json`).

- Checkmate has no built-in date increment. A search of `lua/` for increment/decrement/date found only the `os.date` defaults in `config/defaults.lua`.
- `opts.keys` accepts a function `rhs` (`config/validate.lua:97-136`). Keys are mapped buffer-local in checkmate buffers (`buffer/init.lua:300-306`).
- User `keys` fully replace the default keys (`config/init.lua:535-539`). The defaults use the `<leader>T` prefix, so only the keys in `lua/misc/checkmate.lua` exist under `<leader>t`.
- User `metadata` entries replace defaults per tag name (`config/init.lua:546-550`). `done` is the user's; `priority` and `started` keep their defaults (`<leader>Tp`, `<leader>Ts`).
- `checkmate.Todo.get_metadata` is a closure, not a method. Call it as `todo.get_metadata("done")` (`lib/todo_item.lua:111-122`).
- `get_metadata` and `update_metadata` both match the literal tag text (`lib/todo_item.lua:114`, `init.lua:955`). Alias tags like `@completed(...)` are not found.
- `update_metadata` with an existing tag takes the update path. It fires `on_change` only, not `on_add` (`api.lua:1188-1260`).
- In visual mode, `update_metadata` writes the same value to every selected todo (`init.lua:953-963`).

## Empirical Tests (this session)

- Pure date math via `nvim -l`: 10/01/26 -1 = 09/30/26, 01/01/27 -1 = 12/31/26, 12/31/26 +1 = 01/01/27, 03/01/28 -1 = 02/29/28, 02/28/27 +1 = 03/01/27, 03/08/26 +1 = 03/09/26 (DST day). All pass.
- Headless run with the real config: shift works with the cursor anywhere on the todo line. A todo without `@done` gets a warning and no change. One `undo` reverts one shift.
- Count prefix: `3<leader>t,` shifted 10/01/26 to 09/28/26 through a real keypress.

## Unverified Claims

- Dot-repeat (`.`) does not repeat the shift. Not tested; inferred from the mapping not setting `operatorfunc`. Low priority.

## What Worked

- Reading checkmate's public API in `lua/checkmate/init.lua` and the config merge in `config/init.lua`.
- Headless `nvim --headless file.md -c "luafile test.lua"` with `vim.defer_fn` plus `vim.wait` to let checkmate attach.

## What Didn't Work / Dead Ends

- `timeout` is not installed on macOS (exit 127). Run headless nvim directly and quit with `qa!` inside the script.

## What Ultimately Worked

A local `shift_done_date(days)` in `lua/misc/checkmate.lua`: `get_todo()`, `todo.get_metadata("done")`, parse `^(%d%d)/(%d%d)/(%d%d)$`, `os.time` with `day = dd + days * vim.v.count1` and `hour = 12`, then `update_metadata("done", os.date("%m/%d/%y", t))`. `os.time` normalizes day overflow into the adjacent month and year.

## Approach for Next Session

1. Done: user picked `<leader>t.` (increment) and `<leader>t,` (decrement).
2. Done: function and two `keys` entries added to `lua/misc/checkmate.lua`. Headless keypress test with the applied config passed. `stylua --check` passed.
3. Done: new keys added to the checkmate tables in `docs/specs/keymaps.md` and `docs/specs/plugins.md`.
4. Open: those tables also list `<leader>ta`, `<leader>tp`, `<leader>ts`, `<leader>t]`, `<leader>t[`, which do not exist. User keys replace defaults, and `priority`/`started` use `<leader>Tp`/`<leader>Ts`. Left as is.

## Key Files Quick Reference

| File | Description |
|-|-|
| `lua/misc/checkmate.lua` | User checkmate spec (keys, states, `done` metadata) |
| `checkmate.nvim/lua/checkmate/init.lua` | Public API: `get_todo`, `update_metadata` |
| `checkmate.nvim/lua/checkmate/lib/todo_item.lua` | `build_todo`, `get_metadata` closure |
| `checkmate.nvim/lua/checkmate/config/init.lua` | Config merge rules for `keys` and `metadata` |
| `checkmate.nvim/lua/checkmate/api.lua` | `add_metadata` update vs insert path |

## Decisions Made

| Decision | Rationale |
|-|-|
| Use checkmate API, not raw buffer edits | Goes through checkmate transactions, works from anywhere on the todo line |
| `hour = 12` in `os.time` | Avoids landing on the wrong day at a DST change |
| Normal mode only | Visual mode would stamp one value on every selected todo |
