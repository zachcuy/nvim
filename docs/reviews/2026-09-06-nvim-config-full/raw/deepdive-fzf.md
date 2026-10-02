---
title: Deep-dive review — lua/search/fzf.lua (fzf-lua spec)
created: 2026-09-06
updated: 2026-09-06
status: final
topics:
  - fzf-lua
  - lazyvim-overrides
  - code-review
---

# Deep-dive: `/Users/zcu/.config/nvim/lua/search/fzf.lua`

Verdict: **1 ISSUE, 5 NO ISSUE**

---

## Q1 — Do all four alt keys exist in `defaults.actions.files`?

**NO ISSUE** — `/Users/zcu/.config/nvim/lua/search/fzf.lua:34-39`

All four exist; no ctrl assignment is `nil`. `config.defaults` is the live defaults table (`config.lua:146`), read lazily per picker call by the globals proxy (`config.lua:84,110-111`) — the same mutation pattern LazyVim uses (`extras/editor/fzf.lua:63,67,74`). No default `keymap.fzf`/`keymap.builtin` entry uses ctrl-o/y/l/g (`defaults.lua:216-252`).

`/Users/zcu/.local/share/nvim/lazy/fzf-lua/lua/fzf-lua/defaults.lua:260-264`:

```lua
      ["alt-q"]  = actions.file_sel_to_qf,
      ["alt-Q"]  = actions.file_sel_to_ll,
      ["alt-i"]  = { fn = actions.toggle_ignore, reuse = true, header = false },
      ["alt-h"]  = { fn = actions.toggle_hidden, reuse = true, header = false },
      ["alt-f"]  = { fn = actions.toggle_follow, reuse = true, header = false },
```

Notes (not issues): the line-38 comment "(files picker only)" is imprecise — `ctrl-g` reaches every `_actions`-inheriting picker lacking its own (buffers, oldfiles, git_files); grep/tags/colorschemes/lsp-live keep theirs via `"keep"` (`config.lua:332`; `defaults.lua:978,1391,1476,1679`). The mutation is non-idempotent, but `:Lazy reload` clears `_.cache` *and* purges the plugin's `package.loaded` (`lazy/core/loader.lua:230,233-236`), so defaults are fresh on re-evaluation.

## Q2 — Does LazyVim define those picker actions, and does its `opts` run first?

**NO ISSUE** — `/Users/zcu/.config/nvim/lua/search/fzf.lua:44-50`

LazyVim defines both. `xtras.lua:79-81` imports the extra inside `lazyvim.plugins` (`config/lazy.lua:20`), before `search` (`:26`); `meta.lua:195` chains fragments in that order and `plugin.lua:453-459` evaluates super first — so the user mutates LazyVim's returned table. No other LazyVim fzf picker carries alt keys: `files` and `grep` are the only `actions` tables in the extra (`lsp`, 164-177, has none; no `git_files`/`live_grep` entry). `live_grep`/`grep_cword`/`grep_visual` normalize against the `"grep"` globals (`providers/grep.lua:18,73,368`), so they inherit the loop's result; only `grep_curbuf` uses a separate key (`:313`), which LazyVim never configures.

`/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/fzf.lua:151-163` (`grep` block is identical minus `cwd_prompt`):

```lua
        files = {
          cwd_prompt = false,
          actions = {
            ["alt-i"] = { actions.toggle_ignore },
            ["alt-h"] = { actions.toggle_hidden },
```

## Q3 — Resulting `opts.grep.rg_opts` string

**NO ISSUE** — `/Users/zcu/.config/nvim/lua/search/fzf.lua:56`

Final string, still ending in `-e`:

```
-g "!.git" -g "!.jj" --column --line-number --no-heading --color=always --smart-case --max-columns=4096 -e
```

LazyVim never sets `opts.grep.rg_opts` (only `grep.actions`, `extras/editor/fzf.lua:158-163`), so nothing is discarded. `no_ignore`/`hidden` insert after the binary rather than appending (`utils.lua:1759`), so `-e` stays last.

`defaults.lua:974-975`:

```lua
  rg_opts        = "--column --line-number --no-heading --color=always --smart-case "
      .. "--max-columns=4096 -e",
```

## Q4 — `<leader>`` literal grep has no trailing `-e`

**ISSUE** — `/Users/zcu/.config/nvim/lua/search/fzf.lua:16`

The query is appended positionally at the end of the command. For `-Wall`, rg receives `-Wall` as a positional argument and parses it as a flag, not a pattern; rg exits non-zero and the failure is swallowed (`make_entry.lua:227-228` appends `" || " .. shell_nop()`), so the picker silently shows nothing. A flag-shaped query (`-i`, `--files`) changes rg's behaviour instead. Fix: end the line-16 string with `-e` (or `--`).

`make_entry.lua:414-423`:

```lua
  local expand_query = function(cmd, fzf_field_index)
    if _G._fzf_lua_is_headless and cmd:match("<query>") then
      return (cmd:gsub("<query>", fzf_field_index))
    else
      return ("%s %s"):format(cmd, fzf_field_index)
```

`make_entry.lua:171-172` names the requirement:

```lua
-- reposition args before ` -e <pattern>` or ` -- <pattern>`
-- enables "-e" and "--fixed-strings --" in `rg_opts` (#781, #794)
```

`ctrl-g` half — **compatible, no issue.** Grep's default `ctrl-g` is `{ actions.grep_lgrep }` (`defaults.lua:978`), a live/fuzzy toggle, preserved against the user's global `ctrl-g` by `"keep"` (`config.lua:332`). Live_grep stores `no_esc = true` with the search under the shared resume key (`providers/grep.lua:105-109`), so `M.grep` skips `rg_escape` (`providers/grep.lua:57`, `make_entry.lua:363`) and the literal query survives the toggle. Cosmetic only: the header still reads "Regex Search" (`core.lua:47-55`).

Counter-argument: leading-dash queries are rare and a user would notice. It still stands — the failure is silent, a valid-flag query corrupts behaviour rather than erroring, upstream documents the terminator, and fzf-lua's own default ends in `-e`.

## Q5 — Do the files defaults already exclude `.git`/`.jj`?

**NO ISSUE** — `/Users/zcu/.config/nvim/lua/search/fzf.lua:58-61`

Comment verified, including "hidden files are already on by default" (`hidden = true`). Command precedence is `fdfind`, then `fd` (`providers/files.lua:35-40`), so here: `fd --color=never --type f --type l --exclude .git --exclude .jj`. With `no_ignore = true` the exact flag added is `--no-ignore` (`defaults.lua:534`, applied at `providers/files.lua:53,68`), inserted after the binary (`utils.lua:1759`): `fd --no-ignore --color=never ...`.

`defaults.lua:530-533`:

```lua
  rg_opts                = [[--color=never --files -g "!.git" -g "!.jj"]],
  fd_opts                = [[--color=never --type f --type l --exclude .git --exclude .jj]],
  dir_opts               = [[/s/b/a:-d]],
  hidden                 = true,
```

## Q6 — `winopts.width/height = 0.90`

**NO ISSUE** — `/Users/zcu/.config/nvim/lua/search/fzf.lua:63-66`

LazyVim sets `winopts` and, per the Q2 merge order, the user mutates that table afterwards — `0.90` wins. Fractions are supported: `win.lua:608-609` routes width/height through `normalize_size`, and fzf-lua's own defaults are fractional (`defaults.lua:143-144`).

`extras/editor/fzf.lua:142-146`:

```lua
        winopts = {
          width = 0.8,
          height = 0.8,
          row = 0.5,
```

`win.lua:566-570`:

```lua
function FzfWin:normalize_size(size, max)
  local _ = self
  if size <= 1 then return math.floor(max * size) end
```

---

## Provenance

**Verified this session (read):** `/Users/zcu/.config/nvim/lua/search/fzf.lua:1-69`; `/Users/zcu/.config/nvim/lua/config/lazy.lua:1-58`; fzf-lua `defaults.lua:138-197,200-280,505-548,960-1004`, `config.lua:20-160,300-360`, `core.lua:1-60`, `make_entry.lua:170-235,255-433,465-487`, `providers/grep.lua:1-115`, `providers/files.lua:20-110`, `actions.lua:360-430,1166-1216`, `utils.lua:1743-1764`, `win.lua:372-402,546-628`, `libuv.lua:464-482,685-703`; LazyVim `plugins/extras/editor/fzf.lua:1-306`, `plugins/init.lua:1-40`, `plugins/xtras.lua:1-82`, `config/init.lua:215-260,311-351`, `util/plugin.lua:1-128`, `util/init.lua:66-128`, `util/json.lua:51-107`; lazy.nvim `core/plugin.lua:411-488`, `core/meta.lua:10-30,166-205`, `core/loader.lua:210-240`.

**Not verified this session (external tool behavior, not in any repo read):**
1. fd's `--exclude` globs remain in effect under `--no-ignore` (Q5).
2. rg's CLI parsing of a leading-dash positional argument as a flag (Q4).
