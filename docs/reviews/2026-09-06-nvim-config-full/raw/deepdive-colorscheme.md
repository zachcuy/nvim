---
title: Colorscheme Load Path Deep-Dive (lume vs. options.lua cursor groups)
created: 2026-09-06
updated: 2026-09-06
status: final
topics:
  - colorscheme
  - lazyvim-load-order
  - guicursor
---

# Deep-dive: colorscheme load path + proposed fix

Scope: `lua/ui/colorscheme.lua`, `lua/config/options.lua:17-39`. Sources read this session are listed at the end.

## Q1 — Current startup order and the empty `*Cursor` groups

**ISSUE** — `/Users/zcu/.config/nvim/lua/config/options.lua:21-25`

(a) `lazyvim/plugins/init.lua:12` runs `require("lazyvim.config").init()` at spec-import time; `lazyvim/config/init.lua:332` `M.load("options")` sources `config.options` there — before any plugin loads. The five `*Cursor` groups exist from that moment.

(b) LazyVim's own spec is `{ "LazyVim/LazyVim", priority = 10000, lazy = false, opts = {} }` (`plugins/init.lua:16`). `loader.lua:124-129` loads start plugins sorted by `priority` (`loader.lua:168-172`), so LazyVim runs first → `loader.lua:387` `require(main).setup(opts)` → `lazyvim/init.lua:7` → `config/init.lua:250-256`:

```lua
    if type(M.colorscheme) == "function" then
      M.colorscheme()
    else
      vim.cmd.colorscheme(M.colorscheme)
```

Default (`config/init.lua:13-15`): `colorscheme = function() require("tokyonight").load() end`.

(c) `tokyonight/init.lua:21` → `tokyonight/theme.lua:11-13`:

```lua
  -- only needed to clear when not the default colorscheme
  if vim.g.colors_name then
    vim.cmd("hi clear")
  end
```

`colors_name` is nil here, so **no clear**; `:16` sets `colors_name = "tokyonight-moon"`. The `*Cursor` groups survive tokyonight.

(d) `ui/colorscheme.lua:4-8` (`lazy = false, priority = 1000`) then runs `vim.cmd("colorscheme lume")` → `lume/colors/lume.lua:1` → `lume/init.lua:17-19` `if vim.g.colors_name then vim.cmd("hi clear") end`. `colors_name` is now truthy, so `hi clear` runs: *"Reset all highlighting to the defaults. Removes all highlighting for groups added by the user."* (`syntax.txt:4880-4881`). lume never redefines them — grep of `lua/lume/groups/**` returns only `Cursor`, `CursorIM`, `CursorLine…` (`editor.lua:22-26`).

Yes, that is the complete causal chain. `Comment`/`@comment` survive only because `ui/colorscheme.lua:9-10` re-set them *after* the `colorscheme` command.

**Correction to the supplied facts:** `lCursor` is **not** defined by lume (no match in the whole plugin tree); it is a Neovim built-in group (`syntax.txt:5159-5162`) restored by `hi clear`. Symptom of the empty groups: shape/blink still apply, but the TUI falls back to host-terminal cursor colors (`options.txt:3056-3059`).

**Counter-argument:** one could argue the config "works" because the cursor is still visible. It does not — the intended white/yellow distinction (CLAUDE.md:33) is silently absent. Issue stands.

## Q2 — Order under the proposed fix

**NO ISSUE.** `loader.lua:30-34`:

```lua
  vim.api.nvim_create_autocmd("ColorSchemePre", {
    callback = function(event)
      M.colorscheme(event.match)
```

→ `loader.lua:515-524` finds the unloaded plugin owning `colors/lume.lua` and calls `M.load(plugin, { colorscheme = name })` → `M.load` (`:180-199`) → `M._load` (`:313`). Inside `_load`: `add_to_rtp` (`:345`), `packadd` (`:359`, which sources only `plugin/`, `ftdetect/`, `after/plugin` — `:424-430`), then `:361-363 if plugin.config or plugin.opts then M.config(plugin) end` → `:383-387` `require(main).setup(opts)`. `get_main` (`:399-421`) returns `"lume"` by exact normname match (`lua/lume/init.lua` exists). So `require("lume").setup(opts)` runs **before** `:colorscheme` sources `colors/lume.lua`; `M.config.custom_highlights` is populated when `theme.apply(M.config)` runs (`lume/init.lua:29`).

On a *re-run* of `:colorscheme lume`, `loader.lua:516-518` early-returns because the name is now color-completable, so `colors/lume.lua` is sourced directly with no second `setup` — `M.config` from the first call persists (`lume/init.lua:10-14`), so `custom_highlights` still apply. This is what makes the Q4 reload argument hold.

## Q3 — `custom_highlights` merge and `@comment`

**NO ISSUE.** `lume/theme.lua:78-80`:

```lua
      for k, v in pairs(custom) do
        groups[k] = vim.tbl_extend("force", groups[k] or {}, v)
      end
```

applied after all core/plugin modules (`:63-69`), so it wins. `@comment` is **not** a link — `lume/groups/syntax.lua:118` `["@comment"] = { fg = fg.comment, italic = italic }` — so the merge yields `{ fg = "#75d7b3", italic = true }` and mint applies. The hypothetical is worth recording: had it been a link, `nvim_set_hl` would ignore the colors — *"If `link` is used in combination with other attributes; only the `link` will take effect"* (`api.txt:1437-1438`) — and `link = false` (or overriding `Comment` alone) would have been required. Not needed here.

## Q4 — Skipped `hi clear` under the fix

**NO ISSUE** for the fix; moving the groups is **REQUIRED**, not merely tidier.

`:colorscheme` itself does not clear: it only sources `colors/{name}.{vim,lua}` and fires `ColorSchemePre`/`ColorScheme` (`syntax.txt:4850-4869`); clearing is the colors file's job by convention (`colors/README.txt:36-38`). Under the fix `colors_name` is nil on the normal startup path, so lume skips `hi clear` — harmless, since the only state present is the defaults that `hi clear` would restore.

Three reasons the move is still required: (1) on a fresh/partial install lazy.nvim loads `install.colorscheme` first (`config.lua:78-82`, `loader.lua:74-82`), setting `colors_name` → lume's `hi clear` *does* run; (2) any later `:colorscheme lume`, `:Lazy reload lume`, or `background` change re-runs `load()` with `colors_name` set and wipes anything not in `custom_highlights`; (3) `options.lua` runs once at init and is never re-applied.

**Counter-argument:** "first load skips the clear, so leaving them in options.lua works." True only for one code path and only until the first reload. Issue stands.

## Q5 — Disabling tokyonight / catppuccin

**NO ISSUE** (and optional, not required). Only reference to tokyonight outside `plugins/colorscheme.lua` is `config/init.lua:14`, inside the default `colorscheme` function, which `config/init.lua:176` `vim.tbl_deep_extend("force", defaults, opts)` replaces with the string `"lume"`; the error fallback is `habamax` (`:261`), not tokyonight. Both plugins are `lazy = true` (`plugins/colorscheme.lua:6,13`) and are never required, so disabling only stops the git clone (`:Lazy clean` will delete them from disk).

catppuccin's `specs` block **is** guarded: `plugins/colorscheme.lua:56` `if (vim.g.colors_name or ""):find("catppuccin") then`. All four catppuccin fragments (LazyVim's `name = "catppuccin"`, the user's `"catppuccin/nvim"` matched by URL at `meta.lua:77-79`, plus the `optional = true` stubs in `extras/coding/blink.lua:205-211` and `extras/editor/overseer.lua:2-8`) share one meta; `_rebuild` (`meta.lua:197`) leaves `plugin.optional == false` because two fragments are non-optional, so `fix_disabled` takes the `self:disable(plugin)` branch (`meta.lua:310-315`) → `del` deletes every fragment (`meta.lua:61-63`) and `fragments.lua:73-77` cascades to the bufferline child. bufferline keeps its own fragments and survives; the optional stubs vanish with no error.

## Q6 — guicursor mode letters

**ISSUE** — `/Users/zcu/.config/nvim/lua/config/options.lua:37-38`, and `:23`, and `CLAUDE.md:33`.

`options.txt:3027-3032`: `o Operator-pending mode`, `c Command-line Normal (append) mode`, `ci Command-line Insert mode`, `cr Command-line Replace mode`.

So `options.lua:38 "o:block-CommandCursor/lCursor-blink…"` styles **operator-pending**, not command mode, contradicting the comment at `:37`. Command-line proper (`c`) sits in `:29 "n-v-c-sm:block-NormalCursor/lCursor"` — white and non-blinking; only the `ci`/`cr` submodes (reached with `<Insert>` in the cmdline) get yellow via `:32`/`:35`. CLAUDE.md:33 ("Yellow blinking in insert/replace/command") is therefore wrong for the common `:` case. `VisualCursor` (`:23`) is referenced by no entry: `v` is in `:29`, `ve` in `:32`. `t` (terminal) is also unstyled.

**Counter-argument:** the author may deliberately want a distinct operator-pending cursor and simply mislabeled the group. Even then the group *name* is misleading and the doc claim is false — and the proposed fix carries `CommandCursor` forward verbatim, so both survive it. Issue stands.

## Verdict: SOUND (for the bug it targets), with one addendum

The fix is correct on every mechanism it relies on: `opts.colorscheme = "lume"` replaces the tokyonight default function; `ColorSchemePre` loads the lazy plugin and runs `require("lume").setup(opts)` before `colors/lume.lua`; `custom_highlights` merges last and wins; `@comment` is a plain table so mint applies; the disables are safe. It also fixes the reload case, which the current `config`-function approach does not. It does **not** address Q6, which lives in the same lines it edits. Addendum (design choice on where `o` belongs is the user's — the intent is not in source):

```lua
-- lua/config/options.lua (replacing the guicursor block)
vim.opt.guicursor = {
  "n-v-o-sm:block-NormalCursor/lCursor",
  "i-ci-ve:block-InsertCursor/lCursor-blinkwait700-blinkon400-blinkoff250",
  "r-cr:block-ReplaceCursor/lCursor-blinkwait700-blinkon400-blinkoff250",
  "c:block-CommandCursor/lCursor-blinkwait700-blinkon400-blinkoff250",
}
```

`VisualCursor` can then be dropped (unused), and `CommandCursor` must stay in `custom_highlights`.

## Files read this session

- `/Users/zcu/.config/nvim/lua/ui/colorscheme.lua:1-13`; `lua/config/options.lua:1-60`; `lua/config/lazy.lua:1-58`; grep of `lua/**` for colorscheme/tokyonight/catppuccin/nvim_set_hl
- LazyVim: `config/init.lua:1-467`, `init.lua:1-11`, `plugins/init.lua:1-40`, `plugins/colorscheme.lua:1-63`, `plugins/extras/coding/blink.lua:198-213`, `plugins/extras/editor/overseer.lua:1-14`
- lazy.nvim: `core/loader.lua:24-38,68-85,100-215,255-460,509-529`, `core/plugin.lua:142-212,316-343`, `core/meta.lua:27-360`, `core/fragments.lua:1-175`, `core/config.lua:74-86,279-287`
- lume: `colors/lume.lua:1`, `lua/lume/init.lua:1-36`, `lua/lume/theme.lua:1-107`, `lua/lume/groups/syntax.lua:1-20,110-125`, grep of `lua/lume/groups/**` for `Cursor`
- tokyonight: `lua/tokyonight/init.lua:8-27`, `lua/tokyonight/theme.lua:1-24`
- Neovim 0.11.4 runtime docs: `options.txt:3005-3064`, `syntax.txt:4843-4891,5156-5164`, `api.txt:1425-1447`, `colors/README.txt:1-72`
