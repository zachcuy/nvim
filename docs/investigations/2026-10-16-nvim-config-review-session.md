---
title: Session notes for the 2026-10-16 Neovim config review
created: 2026-10-16
updated: 2026-10-16
status: final
topics:
  - code-review
  - nvim-config
  - tmux
  - session-knowledge
---

Findings are in `docs/reviews/2026-10-16-nvim-config-review.md`. This file covers how they were found.

# Verified Facts

- The 2026-09-06 review was not applied. `git diff --stat 5a320bc HEAD` shows only review docs, `lua/misc/checkmate.lua` (+37, date shift), two one-line doc edits, and `lazy-lock.json`.
- Runtime state after VeryLazy: the five `*Cursor` highlight groups are empty; tokyonight and LuaSnip are loaded; blink snippets preset is `default`; the LazyVim picker is fzf; Snacks explorer and picker are enabled; Oil wins directory buffers (`nvim /tmp/probe_dir` opens `oil:///private/tmp/probe_dir/`).
- tmux server `extended-keys` is `off`. With `off`, `C-S-h` arrives as `08`, `C-i` as `09`, `C-.` as `2e`. With `on` plus `csi-u`, every one is distinct.
- In a C buffer, `<cword>` on `ptr->field-1` gives `ptr-` and `field-1`.
- Stock scss does not add `-` to `iskeyword`. The `sass.vim:19` guard has a stray `]`.
- conform markdown list is `{ "prettier", "markdownlint-cli2", "markdown-toc" }` at runtime, from LazyVim's markdown extra.
- `/usr/bin/python3` has no pynvim. The Node provider has no `neovim` package.

# Unverified Claims

| Claim | Priority | Why unverified |
|-|-|-|
| kitty sends extended keys to tmux once `terminal-features 'xterm-kitty:extkeys'` is set | High | Needs a physical keypress |
| blink `<C-.>` inside tmux types a literal `.` | Medium | Derived from pane bytes, not seen in a live session |
| Select-mode `p` gives `P` over a snippet placeholder | Low | Derived from the mapping |
| Prior M1, M7, M9 mechanisms | Low | Source unchanged; deep code paths not re-read |
| LuaSnip costs about 7.8 ms at startup | Low | Number from the prior review, not re-measured |

# What Worked

- Headless runtime probes. `nvim --headless -i NONE -c "luafile probe.lua"` with a VimEnter autocmd that fires `UIEnter` by hand, because lazy.nvim waits for `UIEnter` before VeryLazy and headless never sends it. The probe dumps to a file, then `qa!`. `-i NONE` keeps shada untouched.
- `vim.fn.execute("verbose nmap X")` shows which plugin file owns a mapping. That found the arrow/flash split on `;`.
- An isolated tmux server (`tmux -L probe -f /dev/null`), a pane running `sh -c 'stty raw -echo; head -c N > file'`, `send-keys`, then `xxd`. This shows exactly what tmux sends a program for each key. Sending `printf '\033[>4;2m'` first plays the part of Neovim's modifyOtherKeys request.
- `:checkhealth which-key` found the `s`/`sv` overlap without any manual mapping review.
- `nvim --clean` for stock ftplugin behavior, so the user's global options do not mask it.

# What Didn't Work / Dead Ends

- `timeout` does not exist on macOS (exit 127). Use the probe's own `vim.defer_fn` safety quit instead.
- `strings` on `~/.local/share/bob/nvim-bin/nvim` returns nothing because it is bob's shim. The real binaries are in `~/.local/share/bob/v0.11.4/bin/nvim`. The answer was in `runtime/doc/tui.txt` anyway.
- `maparg(vim.keycode("<C-S-h>"), "n")` returned nothing even though the map exists. Use `verbose nmap <C-S-h>` instead.
- Suspected that the Snacks explorer and Oil both take over directory buffers. Tested: Oil wins. Not a finding.
- Looked for a local repo with `node_modules`/`target` to time the fzf `no_ignore` cost. Only tool-install directories exist on this machine, which is not representative. Dropped the measurement.
- The first draft said SCSS gets `-` from `sass.vim`. A `--clean` test showed the guard never matches. Read the guard, do not assume it from the indentation.

# What Ultimately Worked

Reading every config file directly (about 1,500 lines, so no subagents were needed), then checking each claim with a runtime probe, not by reasoning from source. The tmux finding came from noticing `TERM_PROGRAM=tmux` during environment checks and testing the key path byte by byte.

# Approach for Next Session

1. Ask the user which of the open questions they have decided (prior fix list, `iskeyword` scope, tmux change).
2. If tmux changes: apply it in `~/.config/tmux/tmux.conf`, reload, and do the live `<C-v><C-S-h>` test in insert mode.
3. Apply the prior fixes in the order from `report.md` "Merge Criteria", plus N3 (delete `keymaps.lua:25-27`) and N7 (providers).
4. Re-run the probe scripts (`/tmp/nvim_probe*.lua`; recreate them from the method above if `/tmp` was cleared) to confirm each fix.
5. Update the docs (H5) in the same change as the code.

# Key Files Quick Reference

| Path | What it is |
|-|-|
| `docs/reviews/2026-09-06-nvim-config-full/raw/report.md` | Prior review, still unapplied |
| `docs/reviews/2026-10-16-nvim-config-review.md` | This review's findings |
| `lua/config/options.lua` | `iskeyword`, guicursor, providers |
| `lua/config/keymaps.lua` | `j`/`k`, resize, `bufdo`, `keymap.del` |
| `lua/search/fzf.lua` | `no_ignore`, literal grep `rg_opts` |
| `~/.config/tmux/tmux.conf` | No `extended-keys` line (outside this repo) |
| `~/.config/kitty/kitty.conf:49-52` | `kitty_mod+h/j/k/l` set to `no_op` |
| `~/.local/share/nvim/lazy/flash.nvim/lua/flash/plugins/char.lua:109-115` | flash skips `;`/`,` when already mapped |
| `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/lang/markdown.lua:13-45` | Markdown conform setup and its conditions |

# Decisions Made

| Decision | Rationale |
|-|-|
| No config edits | User asked for a review; the project guideline says to confirm root cause before changing anything |
| Did not use deep-code-review | User asked for that explicitly |
| Re-verified prior findings at runtime instead of citing the report | The prior report is hearsay this session |
| Recommend tmux `extended-keys on`, not `always` | `on` affects only programs that ask for it; Neovim asks (`tui.txt:167-170`) |
| Treat `no_ignore` and `iskeyword` as decisions, not bugs | Both look deliberate (`cd512b0`, an explicit comment) and serve a real purpose |
