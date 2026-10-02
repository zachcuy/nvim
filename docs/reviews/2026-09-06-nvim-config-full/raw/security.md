## MEDIUM: `<leader>r` "Search and Replace Current File" silently widens to the whole cwd for unnamed buffers
Location: /Users/zcu/.config/nvim/lua/config/keymaps.lua:72
Evidence:
```lua
  [[:lua require('grug-far').open({ prefills = { paths = vim.fn.expand("%"), flags = '-F -i' } })<CR>]],
  { noremap = true, silent = true, desc = "Search and Replace Current File" }
```
Mechanism: `vim.fn.expand("%")` returns `""` for an unnamed buffer (`:enew`, a scratch buffer, the startup buffer), and grug-far's ripgrep engine only appends path arguments when the field is non-empty — `if #inputs.paths > 0 then table.insert(args, '--')` (/Users/zcu/.local/share/nvim/lazy/grug-far.nvim/lua/grug-far/engine/ripgrep/getArgs.lua:86-93) — so rg falls back to its default of the entire cwd, and a replace launched from a keymap labelled "Current File" rewrites every matching file under cwd. The replace path is governed by the same gate: `fetchFilteredFilesList` builds the file list with `paths = inputs.paths` through the same `getArgs` (/Users/zcu/.local/share/nvim/lazy/grug-far.nvim/lua/grug-far/engine/ripgrep/fetchFilteredFilesList.lua:18-31), and each returned file is overwritten by `utils.overwriteFileAsync(file, content, ...)` (/Users/zcu/.local/share/nvim/lazy/grug-far.nvim/lua/grug-far/engine/ripgrep/replaceInMatchedFiles.lua:28, :103).
Fix: guard the prefill the way the sibling keymap already does (`vim.bo.buftype == ""`, /Users/zcu/.config/nvim/lua/search/grug-far.lua:10) and bail with a notify when `vim.fn.expand("%")` is empty; escape spaces before the path reaches the `paths` field (`vim.fn.expand("%"):gsub(" ", "\\ ")`), or build the whole call in a Lua function instead of a `:lua` command string.
Confidence: HIGH
Counter-argument: grug-far is interactive — the Paths input line and the full match list render in the grug-far buffer before the user presses the replace key, so an empty Paths field is on screen and the destructive step is a separate deliberate keystroke. It still stands because (a) an *empty* field reads as "no filter yet", not "every file under cwd", which is exactly where the visual cue is weakest, (b) the author already applies the `buftype == ""` guard in `lua/search/grug-far.lua:10`, so this is an inconsistency rather than a deliberate design, and (c) grug-far confirms only when the replacement is the empty string (`vim.fn.confirm('Replace matches with empty string?', '&yes\n&cancel')`, /Users/zcu/.local/share/nvim/lazy/grug-far.nvim/lua/grug-far/engine/ripgrep/replace.lua:145) — a non-empty replacement across the whole cwd runs unconfirmed.

## MEDIUM: the same prefill is not space-escaped, so a path containing a space is split into two search paths
Location: /Users/zcu/.config/nvim/lua/config/keymaps.lua:72
Evidence:
```lua
  local _pathsStr = vim.trim(pathsStr:gsub('\n', ' '))
  ...
    j = string.find(_pathsStr, ' ', j, true)
    ...
      local path = string.gsub(_pathsStr:sub(i, j - 1), '\\ ', ' ')
```
(/Users/zcu/.local/share/nvim/lazy/grug-far.nvim/lua/grug-far/utils.lua:388-413)
Mechanism: `splitPaths` treats an unescaped space as a path separator and only un-escapes `\ `, so `expand("%")` for `my notes.md` reaches rg as the two paths `my` and `notes.md` — the file the user targeted is never searched, and the second token is resolved against cwd (`M.normalizePath`, utils.lua:644-655) so an unrelated same-named file under cwd is searched and replaced instead. rg's error for the token that does not resolve does not stop the run: grug-far reports a command that produced stdout *and* stderr as success — `or (code == 0 or (hadStdout and errorMessage and #errorMessage > 0))` … `on_finish(isSuccess and 'success' or 'error', errorMessage)` (/Users/zcu/.local/share/nvim/lazy/grug-far.nvim/lua/grug-far/engine/fetchCommandOutput.lua:61-66, with the intent stated in the comment at :62-64).
Fix: same as above — escape spaces (`:gsub(" ", "\\ ")`) in the value passed to `prefills.paths`.
Confidence: HIGH
Counter-argument: the mis-split is visible in the Paths field and the results list names the files it matched, so a user who reads the buffer sees the wrong file. It still stands because the failure is silent by design in grug-far (the missing-path error is deliberately downgraded to success when other output exists), and paths with spaces are common enough on macOS (`~/Library/Application Support/...`, Desktop files) that the keymap will hit it without any adversary.

---

## Checked and cleared (no finding filed)

- **`delete_to_trash = true`** (lua/ui/oil.lua:57): oil's macOS trash is pure libuv filesystem work — `M.delete_to_trash` does `fs.recursive_move(stat_type, path, dest, vim.schedule_wrap(cb))` into `get_trash_dir()` (/Users/zcu/.local/share/nvim/lazy/oil.nvim/lua/oil/adapters/trash/mac.lua:203-230). No shell, no `osascript`, so a hostile filename cannot inject.
- **`osascript` in oil**: the only two sites are `lua/oil/clipboard.lua:206-215` (copy) and `:308-316` (paste). Both pass fixed script text as separate `argv` elements to `vim.fn.jobstart(cmd, ...)` (clipboard.lua:247, :344); the copy site appends the path as an `args` element consumed by `on run args`, and the paste site passes no path at all — no string interpolation into the script in either. Neither action is bound by oil's `default_config.keymaps` (/Users/zcu/.local/share/nvim/lazy/oil.nvim/lua/oil/config.lua:60-76) nor by this config.
- **`vim.fn.jobstart({ "open", dir }, { detach = true })`** (lua/ui/oil.lua:113): table `argv`, no shell interpretation; `dir` is `nil`-guarded at lines 108-111. Oil's own `gx` (`actions.open_external`) likewise routes through `vim.ui.open(path)` on this Neovim version, falling back to argv tables from `get_open_cmd` (/Users/zcu/.local/share/nvim/lazy/oil.nvim/lua/oil/actions.lua:296-329).
- **fzf `no_ignore` / `hidden`** (lua/search/fzf.lua:16, 54-61): the `rg_opts` at lines 16 and 56 are static string literals concatenated with fzf-lua's own defaults — no user-controlled text is interpolated, so no argument injection. The gitignored/hidden expansion can surface `.env`-style files in the picker and preview, but every sink is the user's own screen, quickfix list, and buffers on their own machine; this config has no network or persistence sink for that content, so there is no exposure mechanism to state.
- **`OilActionsPost` buffer deletion** (lua/ui/oil.lua:152-176): `force = true` is gated by `name ~= "" and not vim.bo[bufnr].modified`, so unsaved work is never discarded; `canonical_path` resolves the parent via `vim.uv.fs_realpath` and falls back to `vim.fs.normalize`, which cannot match a real path against a URL-named buffer.
- **No RPC/server/exrc surface**: grep for `serverstart|--listen|rpcrequest|rpcnotify|exrc|shellcmdflag|io.popen|:!` across `/Users/zcu/.config/nvim/**/*.lua` returns only `luasnip.lua:7,9` (`lazy_load`) and `lazy.lua:4` — nothing exposes a listening socket or sources untrusted project-local config.
- **Bootstrap and `version = false`** (lua/config/lazy.lua:1-14, 36): HTTPS clone via `vim.fn.system` with a table `argv` and `--branch=stable`; these are unmodified LazyVim starter defaults, not a weakening of a default, and `lazy-lock.json` is present at the repo root and not covered by `.gitignore` (`.gitignore:1-9`).
- **Deserialization**: `snippets/` contains only `cpp.json` and `rust.json`; `rust.json` (read in full) is plain VSCode snippet bodies. LuaSnip's vscode loader is pointed at that directory with no `package.json` contribution manifest, so there is no Lua/eval path. `.neoconf.json` is inert because neoconf.nvim is not installed (runtime-facts:56).
- **Credentials**: grep for `token|api[_-]?key|password|secret|Bearer|ssh-rsa|BEGIN … PRIVATE KEY` over the tracked config (excluding `docs/`) returns no matches.
