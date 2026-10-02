---
title: Data Contract Review — plugin option schemas vs user config
created: 2026-09-06
updated: 2026-09-06
status: final
topics:
  - data-contract
  - nvim-config
---

# Data Contract Review

Producers = installed plugin sources under `/Users/zcu/.local/share/nvim/lazy/`.
Consumers = `/Users/zcu/.config/nvim/lua/**`. Every row verified by reading the producer.

## Contract Alignment Tables

### lazy.nvim (spec/keys/opts merge)
| # | User key (file:line) | Type | Accepts? | Plugin definition | Note |
|-|-|-|-|-|-|
|1|`spec/defaults.lazy/version/checker.enabled/checker.notify/performance.rtp.disabled_plugins` lazy.lua:18-56|mixed|YES*|lazy/types.lua, view/config.lua|*not read; inferred from clean startup (runtime-facts:7) |
|2|`{"S", false}` flash.lua:9|list|PARTIAL|core/handler/keys.lua:78-87|**F2** mode-scoped id |
|3|`{}` / `{ {} }` disabled.lua:2-5, harpoon2.lua:2-43, scrollbar.lua:1|table|YES|core/util.lua:155 `is_list({})`=true|empty spec, no error |
|4|`opts[1]`,`opts[2]` numbers mini-comment.lua:11,18|number|YES (merged)|util.lua:440 `can_merge` false only for lists|**F6** |
|5|`markdown = {}` nvim-lint.lua:6|table|YES|util.lua:452-470: non-empty list on left ⇒ right replaces|clears list |

### blink.cmp (`langs/blink.lua:4-25`)
| # | User key | Type | Accepts? | Definition | Note |
|-|-|-|-|-|-|
|1|`keymap.preset="default"`|string|YES|blink/cmp/keymap/presets.lua|redundant, LazyVim sets it |
|2|`show / hide / select_and_accept / show_documentation / hide_documentation / show_signature / hide_signature / scroll_documentation_up`,`_down / select_prev`,`_next / fallback`|string|YES*|`blink/cmp/keymap/apply.lua` grep hit at :6 (`'show_signature'`)|*only `show_signature` read directly; rest inferred from clean startup (runtime-facts:7) |

### conform.nvim (`langs/conform.lua:5-22`)
| # | User key | Type | Accepts? | Definition | Note |
|-|-|-|-|-|-|
|1|`formatters_by_ft.<ft> = {names}`|list|YES|init.lua:4, setup :74|shape OK |
|2|`prettierd`,`prettier`,`clang_format`,`stylua`,`rustfmt`|string|YES|conform/formatters/*|names exist |
|3|*missing* `stop_after_first`|—|—|init.lua:24, :367|**F4** all available run |

### nvim-lint / lspconfig / mason
| # | User key | Accepts? | Definition | Note |
|-|-|-|-|-|
|1|`linters_by_ft.markdown = {}` nvim-lint.lua:6|YES|LazyVim linting.lua:47,60-76 `_`/`*` fallbacks unset|no linter runs |
|2|`servers.angularls = false` lsp.lua:6|YES|LazyVim lsp/init.lua servers loop|`false` disables |
|3|`ensure_installed = {"php-debug-adapter"}` dap.lua:10|YES|LazyVim lsp/init.lua:283-293 + `opts_extend` :287|appends, correct repo `mason-org/mason.nvim` |

### fzf-lua (`search/fzf.lua:29-68`)
| # | User key | Accepts? | Definition | Note |
|-|-|-|-|-|
|1|`config.defaults.actions.files["alt-i"/"alt-h"/"alt-q"/"alt-f"]`|YES|defaults.lua:260-264|all four exist |
|2|mutating `config.defaults` pre-setup|YES|config.lua:146 (same table), globals `__index` :84,110-111 reads it live|propagates |
|3|`opts.files.actions`/`opts.grep.actions` alt-i/alt-h|YES|LazyVim extras/editor/fzf.lua:151-163|both exist |
|4|`opts.grep.no_ignore`, `.hidden`|YES|make_entry.lua:278-281|rg flags |
|5|`opts.files.no_ignore`|YES|providers/files.lua:50-53|fd flag |
|6|`opts.grep.rg_opts` built from `defaults.grep.rg_opts`|YES|defaults.lua:974-975|prepend is safe; but see the literal-grep finding for fzf.lua:16 |
|7|`opts.winopts.width/height`|YES*|defaults winopts|*not read; inferred from clean startup |
|8|`rg_opts` passed inline at fzf.lua:16|YES (key)|make_entry.lua:270|value lacks `-e`/`--` terminator — see finding |

### grug-far (`search/grug-far.lua`, `keymaps.lua:72`, `ui/oil.lua:80-100`)
| # | User key | Accepts? | Definition | Note |
|-|-|-|-|-|
|1|`headerMaxWidth = 80` grug-far.lua:3|**NO**|no match anywhere in grug-far.nvim|**F1** |
|2|`transient`|YES|grug-far.lua:301|controls listed buf |
|3|`prefills.filesFilter/paths/flags`|YES|grug-far.lua:7,13-15|alias `grug.far.Prefills` |
|4|`instanceName`,`staticTitle`|YES|grug-far.lua:278-284|ok |
|5|`has_instance(name)`|YES|grug-far.lua:412|ok |
|6|`open_instance`,`update_instance_prefills(q,prefills,clearOld)`|DEPRECATED|grug-far.lua:501-502, 515-517 `vim.deprecate(...,'soon')`|**F5** |

### oil.nvim (`ui/oil.lua`)
| # | User key | Accepts? | Definition | Note |
|-|-|-|-|-|
|1|`columns.register("filetype", {render, parse})`|YES|oil/columns.lua:15-16,25-27|exact shape |
|2|`constants.FIELD_NAME/FIELD_TYPE`|YES|oil/constants.lua:9-10 (=2,3)|ok |
|3|`columns = {"icon", {"filetype", highlight=}, {"mtime", highlight=}}`|YES|columns.lua:32-34 `util.split_config`|ok |
|4|`delete_to_trash`, `view_options.show_hidden`, `.natural_order`|YES|oil/config.lua:80-88|ok |
|5|keymap values `{callback,desc}`, `"actions.close"`, `"<Nop>"`|YES|oil/keymap_util.lua:11-22,61 — only `actions.`-prefixed strings resolve; others pass through as literal rhs; `actions.close` exists at oil/actions.lua:168|all 3 forms valid |
|6|`OilActionsPost` `data.err`, `data.actions`|YES|oil/mutator/init.lua:425|exact |
|7|`action.type=="delete"`, `action.url`|YES|mutator/init.lua:27-30 `oil.DeleteAction`|url present |
|8|`util.parse_url` 2 returns|YES|oil/util.lua:13-16|(scheme, path) |
|9|`fs.posix_to_os_path`|YES|oil/fs.lua:86|ok |
|10|`get_current_dir()` unguarded at :83|nil-able|see **F8**|`gs` only |

### checkmate.nvim (`misc/checkmate.lua`)
| # | User key | Accepts? | Definition | Note |
|-|-|-|-|-|
|1|`files = {"*.md"}`|YES — replaces|config/init.lua:571 `tbl_deep_extend("force")`; `vim/shared.lua:364-366` `can_merge` false for non-empty lists ⇒ `ret[k]=v`|clean, full replace |
|2|`keys[lhs]={rhs,desc,modes}`|YES|validate.lua:104-130; `prevent_merge` nils defaults|full replace, no dup |
|3|`:Checkmate toggle cancelled|on_hold`|YES|commands.lua:28-35 (`fargs[2]`), dispatch :400-401 slices from depth|arg reaches `M.toggle` |
|4|`M.toggle(state)` sets that state|YES|init.lua:104,132,169|not a 2-way toggle |
|5|`todo_states.*.marker/markdown/type/order`|YES|validate.lua:159-206; `VALID_TODO_STATE_TYPES` :3 = incomplete/complete/inactive|`complete`,`inactive` valid |
|6|`style.CheckmateCancelled*` / `CheckmateOnHold*`|YES|highlights.lua:350-364 + util/string.lua:19-30 snake→Camel (`on_hold`→`OnHold`)|names match exactly |
|7|`metadata.done.{aliases,style,get_value,key,on_add,on_remove,sort_order}`|YES|validate.lua:240-300; defaults.lua:174-186|entry replaces default wholesale |
|8|`enter_insert_after_new`,`smart_toggle.enabled`|YES|defaults.lua:105,124|ok |
|9|`log = {}`|YES|defaults.lua:17-20|no-op (LOW) |

### mini.comment / mini.surround / nvim-spider / treesitter-context / others
| # | User key | Accepts? | Definition | Note |
|-|-|-|-|-|
|1|`options.custom_commentstring` mini-comment.lua:7|YES|mini/comment.lua:415 type-checked fn|**F7** replaces LazyVim's ts fn (extras/coding/mini-comment.lua:7-9) |
|2|numeric `opts[1]`,`opts[2]`|IGNORED|comment.lua:410-426 checks named keys only|**F6** |
|3|`custom_surroundings["("].output.left/right` mini-surround.lua:6-8|YES|mini.surround spec|ok |
|4|`skipInsignificantPunctuation`,`consistentOperatorPending`|YES|nvim-spider/lua/spider/config.lua:6-7|both defaults inverted |
|5|`max_lines`,`trim_scope`,`mode`|YES|treesitter-context/config.lua:53,57,59|values in enum |
|6|`code.enabled=false` markdown.lua:5-7|YES|render-markdown code section|ok |
|7|gitsigns `on_attach` returning `false`|YES|gitsigns/attach.lua:378-379|skips attach; see F11 |
|8|multicursor `matchAddCursor/matchSkipCursor/restoreCursors/handleMouse/handleMouseDrag/handleMouseRelease/toggleCursor/addKeymapLayer/cursorsEnabled/enableCursors/clearCursors`|YES|multicursor-nvim/init.lua:37,41,53,54,61-68 (read :28-72)|all 11 exported |
|9|arrow `show_icons/leader_key/buffer_leader_key`|YES|arrow/init.lua:57-58,77-80|ok |
|10|snacks `picker.sources.recent.sort.fields`|YES|snacks picker config/sources.lua:52,166-186 — identical `sort = { fields = {...} }` shape|`"idx"` field itself not read |
|11|snacks `lazygit.configure`,`lazygit.win.style/wo`,`dashboard.enabled`|YES*|snacks lazygit/dashboard opts|*not read; inferred from clean startup |
|12|bufferline `options.*`, `highlights.buffer_selected.fg`|YES*|bufferline/config.lua (`mode` seen at :632)|*only `mode` seen; rest inferred from clean startup |
|13|luasnip `from_vscode.lazy_load({paths=...})`|YES*|luasnip loaders signature|*not read — but see the luasnip finding: the registry is never queried |
|15|`custom_surroundings` (mini.surround), `code.enabled` (render-markdown), `lume.setup()`|YES*|—|*not read; inferred from clean startup (runtime-facts:29) |
|14|`nvim_replace_termcodes(str,true,false,true)` autocmds.lua:23|YES|(str, from_part, do_lt, special)|correct order |

---

## Findings

10 findings: 0 CRITICAL, 1 HIGH, 7 MEDIUM, 2 LOW.
Dropped during self-critique: "checkmate `files` merges index-wise" — `vim/shared.lua:364-366` `can_merge` refuses to merge non-empty lists, so `{ "*.md" }` replaces the default list cleanly.

## MEDIUM: grug-far `headerMaxWidth` is not a grug-far option (inherited from LazyVim); the whole user spec is a duplicate
Schema: no such key — a repo-wide search of `/Users/zcu/.local/share/nvim/lazy/grug-far.nvim` for `headerMaxWidth|maxWidth|headerMax` returns zero matches; `lua/grug-far/opts.lua` contains only one `header`-related line (`:301`, about help-header mappings).
Consumer: `/Users/zcu/.config/nvim/lua/search/grug-far.lua:3` — `opts = { headerMaxWidth = 80 }`. But LazyVim `plugins/editor.lua:6` passes the identical `opts = { headerMaxWidth = 80 }`, and :8-24 the identical `<leader>sr` function body.
Problem: the key is silently ignored, and deleting it from the user file changes nothing — LazyVim still supplies it. The user file is a verbatim copy of LazyVim's spec with two diffs: `cmd = "GrugFar"` vs LazyVim's `{ "GrugFar", "GrugFarWithin" }` (which narrows nothing, since `cmd` lists are extended, not replaced — `plugin.lua:465` `Util.extend`), and `mode = { "n", "v" }` vs LazyVim's `{ "n", "x" }`. The mode diff yields two co-existing key ids (`<leader>sr (v)` and `<leader>sr (x)` — `handler/keys.lua:49-51`), both bound to equivalent functions; harmless but duplicated.
Fix: delete `lua/search/grug-far.lua` entirely (LazyVim already provides it), and report `headerMaxWidth` upstream to LazyVim.
Confidence: HIGH
Counter-argument: keeping a local copy documents intent. It still stands — the copy adds nothing and drifts from LazyVim on every update.

## MEDIUM: `langs/luasnip.lua` writes to a snippet engine nothing reads
Schema: `blink.cmp/lua/blink/cmp/config/snippets.lua:27` default `preset = 'default'`, and every handler is dispatched through `by_preset` (:9-13) keyed on that preset — `luasnip` handlers only run when `preset = 'luasnip'`. LazyVim's blink spec never sets it: `LazyVim/lua/lazyvim/plugins/coding.lua` has zero matches for `snippets` or `preset`. The user config does not set it either.
Consumer: `/Users/zcu/.config/nvim/lua/langs/luasnip.lua:6-10` — `config` calls `require("luasnip.loaders.from_vscode").lazy_load()` and `lazy_load({ paths = { "~/.config/nvim/snippets" } })`.
Problem: blink expands with `vim.snippet` and sources snippets itself, so the LuaSnip registry those two calls populate is never queried by completion. LuaSnip still loads eagerly at startup (~7.8 ms, runtime-facts:30). Custom snippets in `snippets/` appear in completion only because blink's own default source scans `stdpath('config')/snippets`; editing `paths` in this file has no effect on what completion offers.
Fix: either set `opts.snippets.preset = "luasnip"` on blink.cmp (making this spec live), or delete `langs/luasnip.lua` and rely on blink's own scan plus a direct `rafamadriz/friendly-snippets` spec.
Confidence: HIGH
Counter-argument: LuaSnip is a dependency of something else that needs it — it is not; runtime-facts:30 records that this file is the only spec pulling in LuaSnip and friendly-snippets, and the `coding.luasnip` extra is not enabled.

## HIGH: `{"S", false}` disables flash only in normal mode
Schema: `lazy/core/handler/keys.lua:78-87` — `M.resolve` loops `for _, mode in ipairs(modes)` and calls `M.parse(value, mode)`; `M.parse:49-51` appends `" (" .. ret.mode .. ")"` to `ret.id` when `mode ~= "n"`; `values[keys.id] = nil` only when rhs is `false`.
Consumer: `/Users/zcu/.config/nvim/lua/misc/flash.lua:8-10` — `keys = { {"S", false} }` with no `mode`, so `value.mode = "n"` (keys.lua:78) and id = `S`.
Problem: LazyVim registers `{ "S", mode = { "n", "o", "x" }, ... }` (LazyVim `plugins/editor.lua:39`), producing ids `S`, `S (o)`, `S (x)`. The user entry deletes only `S`. `S` in visual and operator-pending mode still lazy-loads flash and runs `flash.treesitter()`. `keymaps.lua:81` maps `S` to `""` in normal mode only, so nothing else covers x/o.
Fix: `{ "S", mode = { "n", "o", "x" }, false }`.
Confidence: HIGH
Counter-argument: one could argue x/o-mode `S` is harmless — but the config's stated intent (docs/specs/keymaps.md) is that `S` is disabled, and visual-mode `S` currently triggers a jump-label UI.

## MEDIUM: conform runs every available formatter; unavailable ones warn on each format
Schema: `conform.nvim/lua/conform/init.lua:345-371` — `resolve_formatters` iterates all names, `add_info` notifies `"Formatter '%s' unavailable: %s"` at WARN when `warn` is set, and only `if stop_after_first and #all_info > 0 then break`. Call site :450-455 passes `not opts.quiet and has_explicit_formatters`. LazyVim sets `default_format_opts.quiet = false` (`plugins/formatting.lua:67-72`).
Consumer: `/Users/zcu/.config/nvim/lua/langs/conform.lua:5-22` — 11 filetypes use `{ "prettierd", "prettier" }`; `c`/`cpp` use `clang_format`; `java` uses `prettier`. No `stop_after_first`.
Problem: (a) `prettier` is not installed (runtime-facts: `prettier=0`, not in Mason bin), so every JS/TS/CSS/JSON/YAML/HTML format emits a WARN even though prettierd succeeded; (b) if prettier is ever installed, both formatters run in sequence on the same buffer; (c) `c`, `cpp`, `java` have zero available formatters (`clang-format=0`, `prettier=0`) — formatting those filetypes only produces a warning.
Fix: add `stop_after_first = true` to opts (or `default_format_opts`), and install `clang-format`/`prettier` via Mason `ensure_installed` if C/C++/Java formatting is wanted.
Confidence: HIGH
Counter-argument: `vim.g.autoformat = false` means this only fires on manual `<leader>cf`, so noise is bounded. It still stands — the fallback pattern `{prettierd, prettier}` is only correct with `stop_after_first`.

## MEDIUM: oil `gs` uses two deprecated grug-far functions
Schema: `grug-far.nvim/lua/grug-far.lua:501-503` `open_instance` calls `vim.deprecate('open_instance(...)', 'get_instance(...):open()', 'soon', 'grug-far.nvim')`; :515-517 the same for `update_instance_prefills` → `get_instance(...):update_prefills()`.
Consumer: `/Users/zcu/.config/nvim/lua/ui/oil.lua:94,96`.
Problem: both emit deprecation notices and are slated for removal ("soon"); `gs` breaks on the next grug-far update that drops them.
Fix: `require("grug-far").get_instance("explorer"):open()` and `:update_prefills(prefills, false)`.
Confidence: HIGH
Counter-argument: `has_instance` (:412) is not deprecated, so only two of three calls need changing — the rest of the block stays.

## MEDIUM: mini-comment autocmds are positional entries in the `opts` table
Schema: lazy.nvim merges opts with `Util.merge` (`core/util.lua:452-470`); `can_merge` (:440-442) is true here because `is_list` returns false for a table holding `options`, `[1]`, `[2]`. mini.comment's `H.setup_config` (`mini/comment.lua:410-426`) only type-checks named keys, so `[1]`/`[2]` are carried into config and ignored. `lazy/core/plugin.lua:184` sets `package.loaded[modname] = nil` before every import, so the spec file re-executes on every spec re-parse.
Consumer: `/Users/zcu/.config/nvim/lua/misc/mini-comment.lua:11-23` — two `vim.api.nvim_create_autocmd(...)` calls placed as unkeyed table entries inside `opts`.
Problem: (a) the autocmds are created at spec-parse time, so `event = "VeryLazy"` does not gate them (the global `formatoptions` strip runs at startup — runtime-facts shows `formatoptions = "jtqnl"`); (b) neither autocmd has a `group`, so every re-parse of the spec (the `package.loaded` reset at `plugin.lua:184` guarantees re-execution) adds another uncleanable copy; (c) their return values (numeric ids) become plugin config keys.
Fix: move both to `lua/config/autocmds.lua` with `vim.api.nvim_create_augroup("<name>", { clear = true })`.
Confidence: HIGH
Counter-argument: it works today and the duplicates are idempotent (setting the same commentstring / formatoptions twice is harmless). It still stands — it is a schema-slot misuse whose cost appears on reload and on any future non-idempotent callback.

## MEDIUM: `custom_commentstring` override drops the ts-context integration
Schema: LazyVim `plugins/extras/coding/mini-comment.lua:7-9` sets `custom_commentstring` to `require("ts_context_commentstring.internal").calculate_commentstring() or vim.bo.commentstring`, and installs `nvim-ts-context-commentstring` (:13-19).
Consumer: `/Users/zcu/.config/nvim/lua/misc/mini-comment.lua:7-9` returns plain `vim.bo.commentstring`. `Util.merge` replaces the function at the same key path.
Problem: commenting inside embedded languages (JSX/TSX blocks, Angular inline templates, `<style>`/`<script>` in HTML) now uses the host filetype's commentstring. The `mini-comment` extra is enabled and `nvim-ts-context-commentstring` is still installed but unreachable.
Fix: if intentional, keep and drop the dependency; if not, restore the LazyVim function and only add the C/C++ override.
Confidence: HIGH (mechanism), MEDIUM (intent unknown)
Counter-argument: the user may only edit single-language files. It still stands: the `typescript`/`tailwind`/`angular` extras are enabled, which is exactly the embedded-language case.

## MEDIUM: the literal-grep `rg_opts` omits the `-e` pattern terminator every fzf-lua default carries
Schema: `fzf-lua/lua/fzf-lua/defaults.lua:974-975` — the grep default is `"--column --line-number --no-heading --color=always --smart-case --max-columns=4096 -e"`, ending in `-e`. `make_entry.lua:171-172` documents the reason: "reposition args before ` -e <pattern>` or ` -- <pattern>` — enables `-e` and `--fixed-strings --` in `rg_opts` (#781, #794)"; `:270` builds the command as `string.format("rg %s", opts.rg_opts)` with the query appended after.
Consumer: `/Users/zcu/.config/nvim/lua/search/fzf.lua:14-17` — `rg_opts = '--fixed-strings --column --line-number --no-heading --color=always --smart-case -g "!.git" -g "!.jj"'`.
Problem: no `-e` and no `--`, so the search pattern is appended as a bare argument. A query beginning with `-` (e.g. `-foo`, `--verbose`) is parsed by rg as a flag instead of a pattern. `--max-columns=4096` is also dropped, so a minified line can flood the picker.
Fix: append ` -e` (or ` --`, which the plugin explicitly supports for the `--fixed-strings` case) and re-add `--max-columns=4096`.
Confidence: HIGH
Counter-argument: literal searches rarely start with `-`. It still stands — the helper at `make_entry.lua:177` exists precisely to make terminators work, and every shipped `rg_opts` uses one.

## LOW: two unguarded nil/empty values reach grug-far `prefills.paths`
1. `/Users/zcu/.config/nvim/lua/ui/oil.lua:83` — `local prefills = { paths = oil.get_current_dir() }`. The two sibling keymaps guard it (`:108`, `:124`). For a non-file adapter (e.g. `oil-ssh://`) it returns nil, so the paths field is empty and grug-far searches the whole cwd instead of the shown directory.
2. `/Users/zcu/.config/nvim/lua/config/keymaps.lua:72` — `paths = vim.fn.expand("%")` returns `""` in an unnamed buffer, giving the same silent whole-cwd search under a keymap described as "Search and Replace Current File".
Fix: reuse the nil/empty guard already written at oil.lua:108.
Confidence: HIGH mechanism, LOW impact.
Counter-argument: only file:// adapters and named buffers are used in practice. It stands as a consistency gap against the author's own guarded siblings.

## LOW: four no-op / lossy config values
1. `checkmate.lua:7` `log = {}` deep-merges into defaults (`config/defaults.lua:17-20`) and changes nothing.
2. `checkmate.lua:107-121` `metadata.done` fully replaces the default `done` entry (`config/init.lua:546-550` explicitly nils it) — default `choices`/other fields are dropped, by design of the plugin but worth knowing.
3. `options.lua:120` `sessionoptions` omits `"folds"`, which LazyVim includes (`lazyvim/config/options.lua`) — folds are not restored from sessions.
4. `gitsigns.lua:11-13` calls `orig_on_attach(bufnr)` but does not return its value, so a `false` from a future LazyVim `on_attach` would be swallowed.
Confidence: HIGH
Counter-argument: each is intentional-looking; listed as notes, not defects.

---

## Files Read (producers)
"Read" = full Read tool call. "grep" = matched lines plus context only.
- Read: `lazy.nvim/lua/lazy/core/handler/keys.lua` (1-203); `lazy.nvim/lua/lazy/core/plugin.lua:420-489`; `LazyVim/lua/lazyvim/plugins/editor.lua:1-28`; `LazyVim/lua/lazyvim/plugins/extras/coding/mini-comment.lua:1-21`; `checkmate.nvim/lua/checkmate/commands.lua:374-408`; `checkmate.nvim/lua/checkmate/config/defaults.lua:1-30`; `checkmate.nvim/lua/checkmate/highlights.lua:265-364`; `checkmate.nvim/lua/checkmate/util/string.lua:10-39`; `fzf-lua/lua/fzf-lua/config.lua:55-129,129-142`; `multicursor.nvim/lua/multicursor-nvim/init.lua:28-72`
- grep hits: `lazy.nvim/lua/lazy/core/plugin.lua:180-188`; `lazy.nvim/lua/lazy/core/util.lua:155-165,338-349,440-470`; `bob/v0.11.4/.../runtime/lua/vim/shared.lua:364-431`; `LazyVim/.../formatting.lua:1-77`, `linting.lua:5-81`, `lsp/init.lua:265-294`, `extras/editor/fzf.lua:125-164`, `plugins/coding.lua` (no `snippets|preset` match); `conform.nvim/lua/conform/init.lua:3-110,345-372,450-472`; `checkmate.nvim` `commands.lua:16-260`, `init.lua:104-296,981-1064`, `config/init.lua:71-153,474-597`, `config/defaults.lua` hits at 9,17,105,124,151-186, `config/validate.lua:3-300`, `theme.lua:129-240`; `fzf-lua` `defaults.lua:255-266,526-540,963-995`, `providers/files.lua:49-65`, `make_entry.lua:277-285`, `actions.lua:1203-1211`, `providers/grep.lua` (no match); `oil.nvim` `columns.lua:15-35`, `constants.lua:9-13`, `mutator/init.lua:19-45,385-430,578-589`, `mutator/parser.lua:14-34`, `util.lua:7-16,142-147`, `fs.lua:83-90`, `config.lua:78-88`, `view.lua:22-100`, `keymap_util.lua:3-73`, `actions.lua:166-170`; `grug-far.nvim/lua/grug-far.lua:7-15,212-310,379-520` + repo-wide `headerMaxWidth` search (0 hits) + `opts.lua` header search (1 unrelated hit at :301); `mini.comment/lua/mini/comment.lua:69-73,406-426,455-472,571-576`; `nvim-spider/lua/spider/config.lua:6-7`; `nvim-treesitter-context/lua/treesitter-context/config.lua:4-59`; `gitsigns.nvim/lua/gitsigns/attach.lua:378-379`; `arrow.nvim/lua/arrow/init.lua:57-80` + `ui.lua`,`persist.lua`,`buffer_ui.lua` hits; `snacks.nvim/lua/snacks/picker/config/sources.lua:48-188`; `blink.cmp/lua/blink/cmp/keymap/apply.lua:6`, `config/snippets.lua:1-84`

## Files Read (consumers)
- `/Users/zcu/.config/nvim/docs/reviews/2026-09-06-nvim-config-full/context/runtime-facts.md`
- `/Users/zcu/.config/nvim/docs/reviews/2026-09-06-nvim-config-full/context/config-bundle.txt` (all 1403 lines)
