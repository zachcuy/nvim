---
title: Cross-Review Verdicts J2 (H7, L3)
created: 2026-09-06
updated: 2026-09-06
status: final
topics:
  - code-review
  - fzf-lua
---

## H7: DOWNGRADED to MEDIUM
Original: literal grep (`<leader>``) drops rg's `-e` terminator, so leading-dash queries are parsed as flags.
Verdict: DOWNGRADED to MEDIUM

### Evidence
`/Users/zcu/.local/share/nvim/lazy/fzf-lua/lua/fzf-lua/defaults.lua:974-975`
```lua
  rg_opts        = "--column --line-number --no-heading --color=always --smart-case "
      .. "--max-columns=4096 -e",
```
`/Users/zcu/.config/nvim/lua/search/fzf.lua:16` — user string ends `-g "!.jj"`; no `--max-columns`, no `-e`/`--`.
`/Users/zcu/.local/share/nvim/lazy/fzf-lua/lua/fzf-lua/providers/grep.lua:160` `local cmd0 = get_grep_cmd(opts, core.fzf_query_placeholder, 2)` (live path; `core.lua:1165 M.fzf_query_placeholder = "<query>"`).
`/Users/zcu/.local/share/nvim/lazy/fzf-lua/lua/fzf-lua/make_entry.lua:414-423` — `expand_query` substitutes `<query>` only when the cmd contains it, else `("%s %s"):format(cmd, fzf_field_index)`; `command = expand_query(command, search_query)`.
`make_entry.lua:220` (`M.lgrep`, function-contents branch) `return (s[1] or ""), true` → `no_esc=true`, so `make_entry.lua:363-368` `rg_escape` is skipped; only `libuv.shellescape` (:408) runs.

### Reasoning
Both live-grep contents branches (`grep.lua:171` raw command, `:175-177` → `make_entry.lgrep`) append the query as a trailing positional argument with no `-e`/`--` before it, and neither branch escapes a leading `-` (shell quoting is stripped before rg's argument parser sees it). `rg_insert_args` (make_entry.lua:177-207) is never reached for this string: the `bin2flags` loop (`:379-396`) only fires on a missing `--line-number`/`--column`, and both are present; `utils.toggle_cmd_flag` (utils.lua:1755-1759) inserts `--hidden`/`--no-ignore` after the binary, not at the end. Failure mode is not uniformly empty: an invalid flag (`-Wall`) makes rg exit non-zero → `|| shell_nop()` (make_entry.lua:227-229) → zero rows, while a *valid* rg flag as query (`--files`, `-h`) changes the command and floods the picker with unrelated output. The `--max-columns=4096` loss is real and applies to every query in this picker.
Severity MEDIUM, not HIGH: (a) wrong results only for queries whose first character is `-` — a subset, on one opt-in keymap, with `<leader>/` as a workaround; (b) the `--max-columns` loss only bites on long/minified lines. Not LOW because the outcome is silent (no results, or wrong results) in a search tool.

### Fix Assessment
Correct. Append ` --max-columns=4096 -e` (prefer `-e` over `--`: `rg_insert_args` patterns at make_entry.lua:180-181 are exercised against both, and `-e` matches fzf-lua's own default). No new bug: with `-e` trailing, `rg_insert_args` relocates glob/filename args before it (`:199-203`), and `toggle_cmd_flag` still inserts after `rg`.
Correction to the finding's wording: "fails silently" is only verified as *empty result list*. Whether rg's stderr text surfaces is not verifiable without running nvim — `core.lua:1111-1112` appends `2>&1` to the whole `A || B` string, so under POSIX (Portable Operating System Interface) shell grammar the redirect binds to the `true` on the right of `||`, and in multiprocess mode it binds to the headless wrapper rather than to rg.
`ctrl-g` toggle does not interfere: `config.lua:56-63 resume_opts` merges the saved `__call_opts` (which holds the per-call `rg_opts`), and `grep.lua:105-108 __resume_set` stores `no_esc=true`, so `--fixed-strings` persists and no `rg_escape` backslashes are injected.

Counter-argument: one could argue HIGH because a search tool returning nothing is indistinguishable from "no matches exist", and the literal picker is exactly where dash-prefixed strings get searched. It still stands as MEDIUM: the affected input class is narrow, the keymap is one of three greps, and no data is lost or corrupted.

## L3: DOWNGRADED to NIT
Original: fzf.lua mutates fzf-lua's module-level defaults in place and rebuilds `grep.rg_opts` from raw defaults instead of merged opts.
Verdict: DOWNGRADED to NIT (finding's idempotency claim is FALSE — do not carry it forward)

### Evidence
`/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/fzf.lua:63,67,74` — same idiom:
```lua
        config.defaults.actions.files["ctrl-t"] = require("trouble.sources.fzf").actions.open
      config.defaults.actions.files["ctrl-r"] = function(_, ctx)
      config.defaults.actions.files["alt-c"] = config.defaults.actions.files["ctrl-r"]
```
`/Users/zcu/.local/share/nvim/lazy/fzf-lua/lua/fzf-lua/defaults.lua:260-264` — `alt-q`, `alt-Q`, `alt-i`, `alt-h`, `alt-f` all present, so none of the four ctrl assignments is nil.
`config.lua:84,102,126` — `M.globals.__index` reads `utils.map_get(M.defaults, index)` and clones it on every access, so the mutation is picked up live; `config.lua:331-332` `globals.actions = vim.tbl_extend("keep", globals.actions or {}, globals._actions())` — grep's own `ctrl-g` (`defaults.lua:978`) wins over the files-global `ctrl-g`.
`/Users/zcu/.local/share/nvim/lazy/lazy.nvim/lua/lazy/core/plugin.lua:451-459` — super's `opts` runs first, its result is passed as `ret` to the child function (LazyVim extra = super, user spec = child).
`plugin.lua:433-438` opts values are cached; `loader.lua:229-236` the only cache reset (`deactivate`) also clears the plugin's `package.loaded` modules.

### Reasoning
Every sub-claim is true but non-impacting. Global mutation: framework precedent (LazyVim mutates the same table), disjoint keys (`ctrl-t/ctrl-r/alt-c` vs `alt-i/h/q/f`), and globals are re-derived from defaults on each picker call, so no staleness. "Discards an earlier `rg_opts`": vacuous — `rg /Users/zcu/.local/share/nvim/lazy/LazyVim/lua -e rg_opts` returns no matches and `lua/search/fzf.lua` is the only fzf-lua spec in the user config. "Not idempotent": false as written — line 56 always reads the never-mutated `defaults.grep.rg_opts`, so re-running yields the identical string; the *actions* block is the order-dependent one, and it is guarded because a re-run can only happen via `deactivate`/`reload`, which re-requires `fzf-lua.config` with `alt-i/h/q/f` restored. Merged result ends in `-e`: `'-g "!.git" -g "!.jj" ' .. "--column … --max-columns=4096 -e"`.

### Fix Assessment
The proposed `opts.grep.rg_opts or …` tweak is harmless composability hygiene, not a bug fix — keep it optional. It does not introduce duplicate globs on a re-run either, because LazyVim's opts function returns a fresh table literal each call (`extras/editor/fzf.lua:89`) and `plugin.lua:459` feeds that fresh table to the user's function, so `opts.grep.rg_opts` is nil on every run. The finding's "not idempotent" justification must be dropped; if any hygiene note survives, it is "line 56 would silently drop an upstream `rg_opts` should LazyVim ever set one."

Counter-argument: mutating another module's `defaults` is genuinely fragile if a future fzf-lua release renames keys or if load order changes — a nil copy would silently delete the toggles. It still stands as NIT: the identical risk is already taken by LazyVim itself in the same file, all four source keys exist in the installed version, and the failure would be visible immediately (missing header actions), not silent-and-wrong.

---

Verified this session: /Users/zcu/.config/nvim/lua/search/fzf.lua:1-69; fzf-lua defaults.lua:250-267,530-540,963-998,1374,1409; config.lua:56-160,176-245,331-336,975; make_entry.lua:150-235,260-433; utils.lua:118-120,252-262,1743-1764; providers/grep.lua:12-184,263-335; actions.lua:1166-1196; core.lua:1085-1124,1165-1183; LazyVim extras/editor/fzf.lua:1-189; lazy.nvim plugin.lua:423-486, loader.lua:205-264, handler/init.lua:100-109.
Not verified this session: rg's own argument-parsing and `--max-columns` default (external binary, cannot run); whether rg's stderr text reaches the picker UI (requires running nvim); runtime-facts.md content used only as environment context (macOS/darwin, fzf-lua lazy-loaded).
