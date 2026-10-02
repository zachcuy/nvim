---
title: Cross-review challenger H — cursor highlights, colorscheme load order, guicursor modes
created: 2026-09-06
updated: 2026-09-06
status: final
topics:
  - code-review
  - colorscheme
  - guicursor
---

## H1: CONFIRMED
Original: The five custom `*Cursor` highlight groups are empty at runtime; the documented yellow insert cursor does not exist.
Verdict: CONFIRMED (HIGH)

### Evidence
`/Users/zcu/.config/nvim/lua/config/options.lua:21-25` — five `nvim_set_hl` calls; `:29`, `:32`, `:35`, `:38` reference them from `guicursor`.
`/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/init.lua:332` — `M.load("options")` inside `M.init()`; `:250-256` applies the colorscheme inside `M.setup()`, i.e. after options.
`/Users/zcu/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/init.lua:13-15`:
```lua
  colorscheme = function()
    require("tokyonight").load()
  end,
```
`/Users/zcu/.local/share/nvim/lazy/tokyonight.nvim/lua/tokyonight/theme.lua:11-16` — `if vim.g.colors_name then vim.cmd("hi clear") end` … `vim.g.colors_name = "tokyonight-" .. opts.style`.
`/Users/zcu/.local/share/nvim/lazy/lume/lua/lume/init.lua:17-19`:
```lua
  if vim.g.colors_name then
    vim.cmd("hi clear")
  end
```
`runtime/doc/syntax.txt:4880-4881` — `:hi[ghlight] clear  Reset all highlighting to the defaults.  Removes all highlighting for groups added by the user.`
Grep of `/Users/zcu/.local/share/nvim/lazy/lume/lua/lume/groups/` for `Cursor`: only `Cursor`, `CursorIM`, `CursorLine`, `CursorColumn`, `CursorLineNr` (editor.lua:22-26), `MiniCursorword*`, `NeoTreeCursorLine`, `FlashCursor`. No `NormalCursor`/`InsertCursor`/`VisualCursor`/`ReplaceCursor`/`CommandCursor`, and no `TermCursor`/`lCursor`.
Ground truth (runtime-facts.md:25): all five groups return `{}` after VeryLazy.

### Reasoning
Every link re-verified from source: options.lua runs at LazyVim `init` (before plugins), the five groups are set, then lume's `load()` executes `hi clear` and re-applies only its own group table — which contains none of the five. The verdict is invariant to whether `vim.g.colors_name` is nil at bare startup: tokyonight carries the identical guard (theme.lua:11-13), so if it were already set, the wipe would simply happen one step earlier. `Comment`/`@comment` survive solely because `colorscheme.lua:9-10` re-sets them after `vim.cmd("colorscheme lume")`. The "terminal default cursor colour" consequence is inference from `runtime/doc/options.txt:3057-3059` ("|inverse|/reverse and no group-name are interpreted as host-terminal default cursor colors"), not a runtime measurement — but the empty-group fact is measured, so CLAUDE.md:33 ("Yellow blinking in insert/replace/command, white in normal") is false either way.

### Fix Assessment
SOUND. Each verification point checks out:

(b) `{ "LazyVim/LazyVim", opts = { colorscheme = "lume" } }` reaches the read site: `config/init.lua:176` `options = vim.tbl_deep_extend("force", defaults, opts or {})`, and `:456-464` `setmetatable(M, { __index = ... return options[key] })`, so `M.colorscheme` at `:252-255` is the string `"lume"` → `vim.cmd.colorscheme("lume")`. Ordering: `lazy/core/loader.lua:30-34` `ColorSchemePre` → `M.colorscheme(name)` at `:515-528` → `M.load(plugin, {colorscheme=name})` → `M._load` (`:313-363`): `M.add_to_rtp` at `:345`, `M.packadd` at `:359`, `M.config(plugin)` at `:362`. `M.packadd` (`:424-430`) sources only `plugin/`, `ftdetect/`, `after/plugin/` — never `colors/`; lume has no `plugin/` dir. So `require("lume").setup(opts)` (`M.config` → `:383-388`, `get_main` resolves `"lume"` by exact normname match at `:414-416`) runs *inside* the autocmd, before `:colorscheme` sources `colors/lume.lua` → `require("lume").load()`. The `:516` `getcompletion("", "color")` early return cannot fire on the first load because `lazy = true` keeps lume's dir off the rtp until `:345`.

(c) `lume/lua/lume/theme.lua:71-82` merges `custom_highlights` into `groups` after all core and plugin modules, then `:84-86` applies them — so custom keys win. Neither target is a link: `lume/lua/lume/groups/syntax.lua:11` `Comment = { fg = fg.comment, italic = italic },` and `:118` `["@comment"] = { fg = fg.comment, italic = italic },` are plain tables, so the `vim.tbl_extend("force", groups[k] or {}, v)` at `:79` produces a link-free table and the `runtime/doc/api.txt` link-precedence caveat does not bite. The four `*Cursor` keys have no existing entry, so `groups[k] or {}` yields `{}`.

(d) Re-application survives: `M.config` in `lume/lua/lume/init.lua:10-14` is module state that persists across `load()` calls, and `colors/lume.lua` is `require("lume").load()` unconditionally. On a later `:colorscheme lume` the `:516` guard *does* early-return (lume is now on the rtp), but that only skips re-running `setup` — the colors file still sources and `theme.apply(M.config)` re-applies `custom_highlights`. `:Lazy reload lume` re-runs `M.config` → `setup(opts)`, which is idempotent.

(e) Disabling tokyonight/catppuccin is safe. Grep of `LazyVim/lua` for `tokyonight|catppuccin` returns only: `config/init.lua:11,14` (the default colorscheme fn, replaced by the fix), `plugins/colorscheme.lua:3-62` (the specs themselves, both `lazy = true`), `extras/coding/blink.lua:204-211` and `extras/editor/overseer.lua:1-8` — both `optional = true` spec fragments that no-op when the plugin is absent (and overseer is not an enabled extra). `colorscheme.lua:56` guards with `if (vim.g.colors_name or ""):find("catppuccin")`, which is false under lume. The error fallback at `config/init.lua:259-262` is `vim.cmd.colorscheme("habamax")`, a built-in — not tokyonight.

One caveat, not a defect: the fix drops `VisualCursor` from `custom_highlights`, which is correct only in combination with M12's guicursor rewrite. If M12 is not applied, nothing breaks (`VisualCursor` is referenced by no guicursor entry today either).

Counter-argument: `hi clear` "resets to defaults" rather than deleting, so the groups might survive with default values. They cannot — `runtime/doc/syntax.txt:4881` says "Removes all highlighting for groups added by the user", these five have no built-in default and lume never defines them, and the headless `nvim_get_hl` measurement returns `{}`. Independent of mechanism, the observed state settles it.

---

## M3: DOWNGRADED to LOW
Original: tokyonight loads at startup and is immediately replaced by lume (~1.1 ms); the colorscheme is selected by side effect in a plugin `config` rather than LazyVim's `colorscheme` option.
Verdict: DOWNGRADED to LOW (as an independent finding)

### Evidence
`/Users/zcu/.config/nvim/lua/ui/colorscheme.lua:1-13` — `lazy = false, priority = 1000`, `config = function() require("lume").setup() vim.cmd("colorscheme lume") ... end`. No `LazyVim/LazyVim` spec sets `opts.colorscheme`.
`LazyVim/lua/lazyvim/config/init.lua:13-15` (default colorscheme fn) and `:250-256` (applied inside `LazyVim.track("colorscheme")`).
`tokyonight.nvim/lua/tokyonight/init.lua:8-22` — `M.load` → `require("tokyonight.theme").setup(opts)`, which sets `vim.g.colors_name` (theme.lua:16).
Runtime facts (:29): tokyonight LOADED at startup, ~1.1 ms self-time; total headless startup 46 ms (:7).

### Reasoning
The factual claim is correct and re-verified. The severity is not: 1.1 ms of a 46 ms startup is 2.4%, and the wasted work is one highlight-table application — imperceptible. The finding's real weight is entirely derivative: tokyonight setting `colors_name` (theme.lua:16) is precisely what arms lume's `hi clear` guard, which is H1. Rating it MEDIUM on its own double-counts H1's HIGH severity, since the same one-line change (`opts.colorscheme = "lume"`) resolves both. No LazyVim feature depends on tokyonight being loaded — the only references are the spec itself and `config/init.lua:14`; lualine/noice/snacks/bufferline reach for catppuccin only through `optional = true` fragments (blink.lua:204-211, overseer.lua:1-8, colorscheme.lua:51-61), never tokyonight.

### Fix Assessment
SOUND, same fix as H1. `opts.colorscheme = "lume"` makes `M.colorscheme` a string (init.lua:176 + :456-464), so `:255` `vim.cmd.colorscheme(M.colorscheme)` runs instead of `:253` `M.colorscheme()`, and tokyonight is never required. Adding `{ "folke/tokyonight.nvim", enabled = false }` is optional hardening, not required — with the default fn replaced, nothing requires the module.

Counter-argument: the "selected by side effect" half is an architecture defect independent of timing, arguably worth MEDIUM on its own. It still downgrades: the defect's only measured consequence is H1, which is already reported at HIGH with the identical remediation. A finding whose entire impact is another finding's impact is a duplicate, not a peer.

---

## M12: CONFIRMED
Original: `guicursor` uses `o:` (operator-pending) where the comment and CLAUDE.md say command mode; `VisualCursor` is defined but referenced by no guicursor entry.
Verdict: CONFIRMED (MEDIUM)

### Evidence
`/Users/zcu/.config/nvim/lua/config/options.lua:29` — `"n-v-c-sm:block-NormalCursor/lCursor",`
`:37-38`:
```lua
  -- Command mode: blinking block cursor
  "o:block-CommandCursor/lCursor-blinkwait700-blinkon400-blinkoff250",
```
`runtime/doc/options.txt:3027-3032` — `o  Operator-pending mode` … `c  Command-line Normal (append) mode` … `ci  Command-line Insert mode` … `cr  Command-line Replace mode`.
`runtime/doc/options.txt:3041` — `Default is "block" for each mode.`; `:3052` — `Default is "blinkon0" for each mode.`
`/Users/zcu/.config/nvim/CLAUDE.md:33` — `**Cursor**: Block cursor in all modes. Yellow blinking in insert/replace/command, white in normal.`
Grep of the whole config for `VisualCursor`: only `options.lua:23` (its definition). No guicursor entry names it; `v` is on `:29`, `ve` on `:32`.

### Reasoning
`c` is Command-line Normal (append) — the ordinary state while typing `:wq` — and it sits on `:29` with the white, non-blinking `NormalCursor`. The yellow blinking `CommandCursor` is bound to `o`, operator-pending, so it flashes during the sub-second window after `d`/`c`/`y`. `ci`/`cr` on `:32`/`:35` cover only mid-line editing and overstrike within the command line, so they do not rescue the common case. `VisualCursor` is dead: `v` and `ve` are already claimed by `:29` and `:32`. `t` (terminal) has no entry at all, so per `:3041`/`:3052` terminal mode gets a non-blinking block with no highlight group — Neovim's default `t:block-blinkon500-blinkoff500-TermCursor` (`:3006`) is lost. That is cosmetic and pre-existing; lume defines no `TermCursor` either (grep returned nothing), so the group would fall back to Neovim's built-in default.

Both readings, stated: (A) code is wrong — the comment at `:37` and CLAUDE.md:33 independently say "command", two sources agreeing against one line of code; (B) the author deliberately wanted operator-pending yellow and mislabelled it — then the code is right and both the comment and CLAUDE.md need correcting. Evidence favours (A) 2-to-1, and severity is MEDIUM either way because at minimum a documented behaviour does not exist. This is invisible today only because H1 empties all five groups.

### Fix Assessment
SOUND. `"n-v-o-sm:block-NormalCursor/lCursor"` plus a new `"c:block-CommandCursor/lCursor-blinkwait700-blinkon400-blinkoff250"` puts operator-pending on the neutral group and command-line Normal on the yellow blinking one; `:32` and `:35` are unaffected; deleting `VisualCursor` removes a genuinely unreferenced group. No new bug: every mode letter appears at most once across the list, `sm` stays paired with `n`, and `ve` on `:32` remains dead-but-harmless (it only applies when `'selection'` is `"exclusive"`, and the default is `"inclusive"`).

Two riders. First, the fix must land together with H1's `custom_highlights` block — `CommandCursor` and `NormalCursor` must both be present there, or the rewrite still points at empty groups. Second, reading (B) is not disprovable from source; before deleting the operator-pending yellow, confirm intent with the user. If (B) holds, the code stays and `options.lua:37` + `CLAUDE.md:33` change instead. Optionally re-add `"t:block-blinkon500-blinkoff500-TermCursor"` to restore the Neovim default for terminal buffers — out of scope for M12 as filed.

Counter-argument: `o` mode is so short-lived that the mislabelling has near-zero practical effect, arguing for LOW. It stays MEDIUM because the *documented* behaviour (yellow blinking command-line cursor) is absent from the config entirely, and that is a correctness gap in a user-visible feature, not a latency detail — and CLAUDE.md is loaded as project instructions, so the wrong claim propagates.
