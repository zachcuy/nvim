---
title: Deep-dive - Oil OilActionsPost buffer cleanup and canonical_path
created: 2026-09-06
updated: 2026-09-06
status: final
topics:
  - oil-nvim
  - autocmds
  - code-review
---

# Deep-dive: `OilActionsPost` cleanup + `canonical_path` (`lua/ui/oil.lua:136-176`)

Verdict: **1 ISSUE, 5 NO ISSUE**.

## Q1 - Directory deletes: one action, descendant buffers never cleaned - **ISSUE**

`/Users/zcu/.local/share/nvim/lazy/oil.nvim/lua/oil/mutator/init.lua:172-179`

```lua
      else
        -- DELETE when no create
        add_action({
          type = "delete",
          entry_type = entry[FIELD_TYPE],
          url = cache.get_parent_url(id) .. entry[FIELD_NAME],
        })
```

One action per removed oil line, `entry_type = "directory"`, url = the directory. Recursion is filesystem-level, never action-level: `fs.lua:203-206` `M.recursive_delete = function(entry_type, path, cb) if entry_type ~= "directory" then return uv.fs_unlink(path, cb) end`, and trash uses one call, `adapters/trash/mac.lua:227` `fs.recursive_move(stat_type, path, dest, vim.schedule_wrap(cb))`. `actions` is only ever appended to at `mutator/init.lua:407` (cross-adapter move split), never expanded for descendants. So the exact-equality test at `oil.lua:168` compares `/dir/file.txt` against `/dir` and fails: **buffers inside a deleted directory are never cleaned up**, which is precisely the UI freeze the autocmd exists to prevent.

Counter-argument: exact match is deliberately conservative - a prefix match risks wiping unrelated buffers, and oil's own precedent (`util.lua:285` `if vim.startswith(bufname, src_buf_name) then` inside `update_moved_buffers`, which handles the directory case for moves) itself lacks a trailing-separator guard, so `/dirsuffix/x` would false-positive. It still stands: the payload carries `action.entry_type`, so the directory case is cheap to branch on, and the gap silently defeats the autocmd's stated purpose. Note the fix is not a one-line `vim.startswith`: for every descendant of a deleted directory the parent is gone, so `canonical_path` always takes its fallback branch (see Q5) - a correct fix must realpath the nearest *existing* ancestor and append a separator to the prefix.

## Q2 - `delete_to_trash` does not rewrite the action - **NO ISSUE**

`lua/oil/adapters/files.lua:605-625` - the flag is consulted inside `perform_action`, after the action object is final:

```lua
    if config.delete_to_trash then
      require("oil.adapters.trash").delete_to_trash(path, cb)
    else
      fs.recursive_delete(action.entry_type, path, cb)
    end
```

`type` stays `"delete"` and `url` stays `oil://...`; only the FS implementation changes. `files.lua:536-540` changes just the confirmation label (`" TRASH %s"`). The files adapter defines no `filter_action` (grepped `files.lua`: no match), so `add_action`'s filter at `mutator/init.lua:75` keeps it. The autocmd matches.

## Q3 - `parse_url` returns scheme-with-`://` and a posix path - **NO ISSUE**

`lua/oil/util.lua:16-18`:

```lua
M.parse_url = function(url)
  return url:match("^(.*://)(.*)$")
end
```

Return 1 includes the `://` (`"oil://"`), return 2 is the remainder in posix form. `fs.posix_to_os_path` (`fs.lua:86-99`) is identity on non-Windows and maps `/C/foo` -> `C:\foo` on Windows. This is exactly oil's own helper, `util.lua:247-250`: `local scheme, path = M.parse_url(url) ... return { fs.posix_to_os_path(path) }`. Both returns are nil when there is no `://`, and `oil.lua:163` guards with `if path then`. Correct.

## Q4 - Event site and payload field names - **NO ISSUE**

`lua/oil/mutator/init.lua:423-426`, inside `finish(err)`:

```lua
      vim.api.nvim_exec_autocmds(
        "User",
        { pattern = "OilActionsPost", modeline = false, data = { err = err, actions = actions } }
      )
```

Field names are exactly `data.err` and `data.actions`, matching `oil.lua:155,160`. One nuance: `finish` also fires on partial failure and on cancel (`finish("Canceled")`, `mutator/init.lua:438`), so the early return at `oil.lua:155` skips cleanup for the deletes that already completed before the error. Conservative and correct.

## Q5 - Fallback loses symlink canonicalization - **NO ISSUE** (premise is true)

The premise holds. `canonical_path` is symmetric as a function, but its *inputs* are not: oil URLs are already realpath'd (`files.lua:251-259`, `normalize_url`: `realpath = new_os_path or os_path`) and delete URLs derive from that via `cache.get_parent_url`, while plain file buffer names keep whatever spelling the user typed. When the parent dir is gone, `oil.lua:149` `return vim.fs.normalize(p)` does not resolve symlinks, so target `/private/tmp/foo/bar.txt` never equals buffer name `/tmp/foo/bar.txt`.

Reachable: `try_write_changes` parses every modified oil buffer (`mutator/init.lua:518-530`), `enforce_action_order` schedules child deletes first (`mutator/init.lua:226-227`, `src_trie:accum_children_of(action.url, ret)`), and the event fires only after all actions finish - so the parent is already gone. NO ISSUE because the failure mode is "buffer lingers", i.e. the pre-autocmd behavior: no error, no data loss, and no false positives (realpath is injective over existing dirs, and `not vim.bo[bufnr].modified` at `oil.lua:168` protects unsaved work).

## Q6 - Wiping oil's original buffer - **NO ISSUE**

`actions.close` -> `oil.close` (`lua/oil/actions.lua:168-172`). `lua/oil/init.lua:418-419`:

```lua
  local ok, bufnr = pcall(vim.api.nvim_win_get_var, 0, "oil_original_buffer")
  if ok and vim.api.nvim_buf_is_valid(bufnr) then
```

Invalid handle falls through to `init.lua:429-440` (`pcall(vim.cmd.bprev)`, else `enew`/`quit`, then delete the oil buffer). Every other read of the var is guarded the same way: `init.lua:994`, `init.lua:1004` (`oil_original_alternate`), `init.lua:1303`. Neovim does not recycle buffer numbers, so no stale-handle aliasing. No error path.

## Footnote (in scope, lines 136-176)

`oil.lua:145` calls `vim.uv.fs_realpath` bare, while `lua/config/lazy.lua:2` and oil itself (`fs.lua:4`, `local uv = vim.uv or vim.loop`) hedge. `vim.uv` requires a newer Neovim than `vim.loop`; the running Neovim version was not verified this session.

## Provenance - verified this session

- `/Users/zcu/.config/nvim/lua/ui/oil.lua:1-179`
- `/Users/zcu/.local/share/nvim/lazy/oil.nvim/lua/oil/mutator/init.lua:1-611`
- `/Users/zcu/.local/share/nvim/lazy/oil.nvim/lua/oil/util.lua:1-936`
- `/Users/zcu/.local/share/nvim/lazy/oil.nvim/lua/oil/fs.lua:1-377`
- `/Users/zcu/.local/share/nvim/lazy/oil.nvim/lua/oil/constants.lua:1-13`
- `/Users/zcu/.local/share/nvim/lazy/oil.nvim/lua/oil/adapters/files.lua:500-659` + grep (`realpath|normalize_url|filter_action|url_escape`)
- `/Users/zcu/.local/share/nvim/lazy/oil.nvim/lua/oil/adapters/trash/mac.lua:190-229`
- `/Users/zcu/.local/share/nvim/lazy/oil.nvim/lua/oil/init.lua:395-479`, `978-1009`, plus grep for `oil_original_buffer`
- `/Users/zcu/.local/share/nvim/lazy/oil.nvim/lua/oil/actions.lua:168-172` (grep context)

Not verified this session: the installed Neovim version (footnote only); `lua/oil/cache.lua` (`perform_action` receives a single action and holds no reference to the `actions` list, which is local to `process_actions`, so it cannot expand Q1's action set).
