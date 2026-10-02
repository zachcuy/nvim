# Correctness review findings

## HIGH: `custom_commentstring` override disables treesitter-aware commentstring, breaking comments in embedded languages
Location: /Users/zcu/.config/nvim/lua/misc/mini-comment.lua:7-9
Evidence:
```lua
custom_commentstring = function()
  return vim.bo.commentstring
end,
```
Problem: mini.comment resolves the comment string as `if vim.is_callable(options.custom_commentstring) then cs = options.custom_commentstring(ref_position) end` / `cs = cs or MiniComment.get_commentstring(ref_position)` (mini.comment/lua/mini/comment.lua:461-462). The user function never returns `nil`, so the treesitter injected-language walk in `MiniComment.get_commentstring` (comment.lua:359-401) is unreachable, and LazyVim's replaced default (`require("ts_context_commentstring.internal").calculate_commentstring() or vim.bo.commentstring`, LazyVim extras/coding/mini-comment.lua:7-9) is discarded.
Impact: With the `typescript`, `angular`, `tailwind` and `markdown` extras enabled, `gcc` inside JSX/TSX markup, Angular inline templates, `<style>`/`<script>` blocks in HTML, and fenced code blocks in markdown emits the host-file comment string (`// %s`), producing syntactically invalid code that the user must undo by hand.
Fix: Delete the `custom_commentstring` override so LazyVim's ts-aware function is restored (`nvim-ts-context-commentstring` is installed — lazy-lock.json:47). That alone regresses C, because that plugin ships `c = '/* %s */'` (nvim-ts-context-commentstring/lua/ts_context_commentstring/config.lua:66) which is why the override exists; so also add `opts = { languages = { c = "// %s" } }` for `nvim-ts-context-commentstring`. `cpp` already defaults to `{ __default = '// %s', __multiline = '/* %s */' }` (config.lua:67), so the `c`/`cpp`/`h`/`hpp` FileType autocmd at mini-comment.lua:11-17 becomes redundant.
Confidence: HIGH
Counter-argument: mini.comment's own docs present this exact snippet (comment.lua:92-99) as the supported way to "always use buffer `commentstring` even in case of present active tree-sitter parser", so it is a deliberate, documented option. It still stands: the documented option is offered for users without embedded-language filetypes, and this config enables four extras whose filetypes rely on injected-language comment strings.

## HIGH: `sv` shares a prefix with Flash's `s`, so `s`-then-`v` opens a vsplit instead of jumping
Location: /Users/zcu/.config/nvim/lua/config/keymaps.lua:17
Evidence:
```lua
keymap.set("n", "sv", ":vsplit<Return>", opts)
```
Problem: Flash's `s` is left mapped in normal mode (`lua/misc/flash.lua:8-10` only disables `S`), and runtime-facts:15 confirms both `s` (Flash jump) and `sv` are live with `timeoutlen = 300`. `s` is now an ambiguous prefix.
Impact: Every Flash jump is delayed 300 ms waiting for a possible `v`, and any jump whose first target character is `v` (`value`, `void`, `var`, `vim`, ...) silently opens a vertical split instead of jumping.
Fix: Rebind the split to a non-prefix key (e.g. `<leader>wv`, which LazyVim already provides), or disable Flash's `s` in `lua/misc/flash.lua` if the split is preferred.
Confidence: HIGH
Counter-argument: The author may consciously accept the 300 ms wait and never jump to a `v`-initial target. It still stands because the failure is silent and destructive to window layout — there is no feedback distinguishing "Flash consumed `v`" from "vsplit fired".

## MEDIUM: Oil's delete-buffer cleanup never fires for directory deletes
Location: /Users/zcu/.config/nvim/lua/ui/oil.lua:160-173
Evidence:
```lua
if action.type == "delete" then
  local _, path = oil_util.parse_url(action.url)
  if path then
    local target = canonical_path(oil_fs.posix_to_os_path(path))
```
Problem: Oil emits one `delete` action per deleted entry with `url = cache.get_parent_url(id) .. entry[FIELD_NAME]` and `entry_type = entry[FIELD_TYPE]` (oil.nvim/lua/oil/mutator/init.lua:174-178); for a directory the url is the directory itself, not its contents. The loop only deletes buffers whose canonical name is *equal* to `target`, so nothing matches.
Impact: Deleting a directory in Oil leaves every open buffer for files inside it pointing at a missing path — the exact lingering-buffer / ~1 s UI freeze the block was written to prevent (per the comment at oil.lua:136-139).
Fix: When `action.entry_type == "directory"`, also delete buffers whose canonical name starts with `target .. "/"`.
Confidence: HIGH
Counter-argument: `delete_to_trash = true` (oil.lua:57) means the files still exist in Trash, so Neovim may not treat them as missing. It still stands: the buffers' recorded paths no longer resolve under the original directory, which is the condition the guard targets.

## MEDIUM: Autocommands are created as positional entries inside `opts`, running at spec-parse time and leaking into `MiniComment.setup`
Location: /Users/zcu/.config/nvim/lua/misc/mini-comment.lua:11-23
Evidence:
```lua
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "c", "cpp", "h", "hpp" },
```
Problem: `nvim_create_autocmd` is called while the spec table is being constructed, i.e. during `require("lazy").setup()`, not when mini.comment loads (`event = "VeryLazy"`). Its return values (integers) become `opts[1]` and `opts[2]` and are passed straight into `MiniComment.setup` (`H.setup_config` only does `H.check_type('config', config, 'table', true)` then `vim.tbl_deep_extend`, comment.lua:410-412). No `group` is given, so the autocmds cannot be replaced or cleared.
Impact: The `formatoptions` and `commentstring` behaviour is bound to whether this spec *file* is parsed rather than whether mini.comment is enabled — disabling the plugin leaves both autocmds active — and any re-import of the module stacks duplicate handlers.
Fix: Move both `nvim_create_autocmd` calls into `lua/config/autocmds.lua` (or a `config`/`init` function) under a named `augroup` with `clear = true`, leaving `opts` as pure data.
Confidence: HIGH
Counter-argument: mini.comment tolerates the stray numeric keys and the autocmds do fire, so nothing visibly breaks today. It still stands: an `opts` table is a data contract, and the side effect is invisible to `enabled = false`, `:Lazy` state, and any future strict-key validation in mini.nvim.

## MEDIUM: `cancelled.order` collides with the built-in `checked.order`, making todo cycling non-deterministic
Location: /Users/zcu/.config/nvim/lua/misc/checkmate.lua:85
Evidence:
```lua
      cancelled = {
        marker = "✗",
        markdown = "c", -- Saved as `- [c]`
        type = "complete", -- Counts as "done"
        order = 2,
```
Problem: checkmate's built-in `checked` state also has `order = 2` (checkmate.nvim/lua/checkmate/config/defaults.lua:99-102), and it survives the merge: `config/init.lua:531,570-571` does `config = vim.deepcopy(defaults)` then `vim.tbl_deep_extend("force", config, opts)`, and `prevent_merge` (init.lua:534-551) only clears `keys`, `list_continuation.keys` and per-name `metadata` — never `todo_states`. The state list is then built by iterating `pairs(config.options.todo_states)` and sorted with `table.sort(states, function(a, b) return a.order < b.order end)` (parser/init.lua:207-220). `validate_todo_states` checks duplicate markers and duplicate markdown, but not duplicate orders (validate.lua:149-180).
Impact: `checked` and `cancelled` tie in the sort, so their relative position in the cycle is decided by `pairs()` hash order; `<leader>t=` / `<leader>t-` can visit them in a different order between sessions.
Fix: Give `cancelled` a distinct order (e.g. `order = 3`).
Confidence: HIGH
Counter-argument: Lua's `pairs()` order is usually stable for a fixed table build, so the user may never see a change. It still stands: nothing in checkmate or Lua guarantees it, and `on_hold` already uses `order = 100`, showing distinct values were intended.

## MEDIUM: C/C++ `*` insert mapping fires on any `/`, corrupting glob strings and paths
Location: /Users/zcu/.config/nvim/lua/config/autocmds.lua:24-31
Evidence:
```lua
      local col = vim.fn.col(".")
      local line = vim.fn.getline(".")
      if line:sub(col - 1, col - 1) == "/" then
        vim.api.nvim_feedkeys(close, "n", false)
```
Problem: The only condition is "the previous byte is `/`" — there is no check for string literals, existing comments, or preprocessor lines. `close` is `"*  */<Left><Left><Left>"` (autocmds.lua:23).
Impact: Typing `"src/*.c"`, `"**/*.h"`, `#include <sys/*` or a `*` after `/` inside an already-open `/* ... */` block silently expands to `/*  */`, corrupting the line mid-typing.
Fix: Gate the expansion on the cursor not being inside a string or comment, e.g. bail out when `vim.treesitter.get_captures_at_cursor(0)` contains `string` or `comment` (falling back to `vim.fn.synIDattr` when no parser is attached).
Confidence: HIGH
Counter-argument: `/` immediately followed by `*` is genuinely rare in normal C code, so the author may never hit it. It still stands: glob patterns and paths in build scripts, `#include` lines and log format strings are exactly where `/` precedes `*`, and the corruption is silent and mid-word.

## MEDIUM: Literal-grep keymap drops rg's `-e` terminator, so any query starting with `-` fails
Location: /Users/zcu/.config/nvim/lua/search/fzf.lua:16
Evidence:
```lua
          rg_opts = '--fixed-strings --column --line-number --no-heading --color=always --smart-case -g "!.git" -g "!.jj"',
```
Problem: fzf-lua appends the search query positionally at the end of the command (`("%s %s"):format(cmd, fzf_field_index)`, fzf-lua/lua/fzf-lua/make_entry.lua:414-419). Its own grep default ends with `-e` for exactly this reason (`rg_opts = "--column --line-number --no-heading --color=always --smart-case " .. "--max-columns=4096 -e"`, fzf-lua/lua/fzf-lua/defaults.lua:974-975). This replacement string has no `-e`.
Impact: In the "Grep Literal (cwd)" picker, searching for anything starting with a dash (`-Wall`, `--fixed-strings`, `-->`, `-1`) makes ripgrep parse the query as a flag and exit with an error, so the picker shows no results — in the one picker whose purpose is literal text search. The `opts.grep.rg_opts` edit at fzf.lua:56 is unaffected because it *prefixes* the globs onto the default and keeps the trailing `-e`.
Fix: Append ` -e` to the end of the `rg_opts` string at fzf.lua:16, matching fzf-lua's default.
Confidence: HIGH
Counter-argument: The user may only ever search alphanumeric literals. It still stands: a fixed-strings picker exists precisely for text that regex/flag parsing mangles, and the failure surfaces as an empty result set rather than an obvious error.

## MEDIUM: `<Tab>` mapping removes jumplist-forward (`<C-i>`)
Location: /Users/zcu/.config/nvim/lua/ui/bufferline.lua:7
Evidence:
```lua
      { "<Tab>", "<Cmd>BufferLineCycleNext<CR>", desc = "Next Buffer" },
```
Problem: In a terminal Neovim session `<Tab>` and `<C-i>` are the same byte (0x09), so mapping `<Tab>` also captures `<C-i>`. Nothing in the config restores jumplist-forward on another key (grepped `lua/config/keymaps.lua` — no `<C-i>` or jumplist binding).
Impact: `<C-o>` still walks back through the jumplist but there is no way to walk forward, in a config that uses `gd`/Flash/`n` heavily.
Fix: Add a replacement, e.g. `vim.keymap.set("n", "<C-p>", "<C-i>", { desc = "Jump forward" })`, or move buffer cycling to `<S-h>`/`<S-l>` (LazyVim's default).
Confidence: HIGH
Counter-argument: Under the kitty keyboard protocol the two keys are distinguishable, so this may not bite in the user's terminal. It still stands: the config is branch-shared across machines (`main`, `ubuntu-desktop`) and degrades silently on terminals without that protocol.

## MEDIUM: `java = { "prettier" }` names a formatter that is not installed and has no fallback
Location: /Users/zcu/.config/nvim/lua/langs/conform.lua:10
Evidence:
```lua
        java = { "prettier" },
```
Problem: `prettier` is not on PATH and is not in Mason's bin (runtime-facts:35-36); LazyVim's `formatting.prettier` extra, which installs it, is not enabled (lazyvim.json:2-18). conform filters unavailable formatters and only falls back to LSP when one is attached (`opts.lsp_format ~= "never" and not any_formatters`, conform.nvim/lua/conform/init.lua:517-521); otherwise it reports `"No formatters available for buffer"` (init.lua:553). No Java LSP extra is enabled.
Impact: `<leader>cf` in a Java buffer always reports `"No formatter available"` (LazyVim/lua/lazyvim/util/format.lua:136-138, reached because `force = true`); `vim.g.autoformat = false` (options.lua:138) means this only bites on manual formatting. The other `{ "prettierd", "prettier" }` entries are unaffected because `prettierd` is installed.
Fix: Either enable `lazyvim.plugins.extras.formatting.prettier`, or drop the `java` entry.
Confidence: HIGH
Counter-argument: The `c`/`cpp` → `clang_format` entries look equally broken (clang-format absent) but are rescued by clangd's LSP formatting fallback; the author may assume the same for Java. It still stands: no Java language server is configured, so there is nothing to fall back to.
