---
title: Debugging Guide (nvim-dap)
created: 2026-07-01
updated: 2026-07-01
status: active
topics:
  - debugging
  - dap
  - languages
---

# Debugging Guide

How to use, install, and troubleshoot the debugger in this config. The debugger is
[nvim-dap](https://github.com/mfussenegger/nvim-dap) (Debug Adapter Protocol client)
wired through LazyVim's `dap.core` extra, plus a small local override for PHP.

Covered languages: **Rust, C/C++, TypeScript/JavaScript, PHP, Lua.** Adding others is
a two-line change — see [Adding a language](#adding-a-language).

## TL;DR

1. Open a source file in a supported language.
2. Set a breakpoint: `<leader>db`.
3. Start: `<leader>dc` (pick a configuration when prompted).
4. Step with `<leader>di` / `<leader>dO` / `<leader>do`; inspect with `<leader>du` (UI) and `<leader>de` (eval).
5. Stop: `<leader>dt`.

If nothing happens, the adapter probably isn't installed yet — see [Installation](#installation).

## How it is wired

Three pieces, all version-controlled in this repo:

| Piece | File | What it does |
|-|-|-|
| `dap.core` extra | `lua/config/lazy.lua` (import) | Installs nvim-dap, dap-ui, virtual-text, mason-nvim-dap. Defines all `<leader>d` keymaps. Reads `.vscode/launch.json`. |
| `dap.nlua` extra | `lua/config/lazy.lua` (import) | Lua debugging via `one-small-step-for-vimkind` (osv). |
| PHP override | `lua/langs/dap.lua` | Adds `php-debug-adapter` to Mason's install list (LazyVim defines the PHP adapter but never installs it). |

Per-language adapters and launch configurations come from the **LazyVim language
extras** you already have enabled (`rust`, `clangd`, `typescript`, `php`). Those extras
each ship an `optional = true` nvim-dap block that stays dormant until nvim-dap exists.
Enabling `dap.core` is what activates them — no per-language wiring needed beyond the
PHP install gap.

Adapter binaries are installed by **Mason**. `rust`/`clangd` add `codelldb`,
`typescript` adds `js-debug-adapter`, and `lua/langs/dap.lua` adds `php-debug-adapter`.
`mason-nvim-dap` (installed by `dap.core`) has `automatic_installation = true`, so
adapters for any configured language also install on demand.

## Keymaps

Prefix is `<leader>d` (which-key group "debug"). From `dap.core`:

| Key | Action |
|-|-|
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Breakpoint with condition (prompts) |
| `<leader>dc` | Run / Continue (starts a session, or resumes) |
| `<leader>da` | Run with arguments (prompts) |
| `<leader>dC` | Run to cursor |
| `<leader>dg` | Go to line (no execute) |
| `<leader>di` | Step into |
| `<leader>dO` | Step over |
| `<leader>do` | Step out |
| `<leader>dj` | Down one frame in the call stack |
| `<leader>dk` | Up one frame in the call stack |
| `<leader>dl` | Run last configuration |
| `<leader>dP` | Pause |
| `<leader>dr` | Toggle REPL (in Rust buffers this is remapped to Rust Debuggables — see [Rust](#rust)) |
| `<leader>ds` | Session info |
| `<leader>dt` | Terminate |
| `<leader>dw` | Widgets (hover value under cursor) |
| `<leader>du` | Toggle the dap-ui panels |
| `<leader>de` | Evaluate expression (normal + visual) |

Notes:

- `<leader>du` is the reliable way to open/close the dap-ui panels (scopes, stack,
  breakpoints, watches, REPL). dap-ui also opens automatically when a session starts
  and closes when it ends.
- Continue with **no** breakpoint set will run the program to completion — set a
  breakpoint first with `<leader>db`.

## Per-language usage

### Rust

- **Adapter:** `codelldb` (installed).
- **Start:** open a `.rs` file in a Cargo project and press **`<leader>dr`** → this runs
  `:RustLsp debuggables`, which lists runnable/debuggable targets (binaries, tests,
  examples) detected by rustaceanvim. Pick one.
- `<leader>dr` is remapped by rustaceanvim to "Rust Debuggables" *only inside Rust
  buffers*. Everywhere else `<leader>dr` remains "Toggle REPL".
- You can also use the generic `<leader>dc` and pick a `codelldb` configuration.
- **Build:** rustaceanvim compiles the chosen target in debug mode automatically
  (`cargo` debug profile includes symbols). No manual `-g` needed.

### C / C++

- **Adapter:** `codelldb` (installed).
- **Prerequisite:** compile **with debug symbols**. Examples:
  - `gcc -g -O0 main.c -o main`
  - `clang++ -g -O0 main.cpp -o main`
  - CMake: `cmake -DCMAKE_BUILD_TYPE=Debug ..`
- **Start:** open the `.c`/`.cpp` file, `<leader>dc`, pick **"Launch file"**. You are
  prompted for the path to the executable — enter the compiled binary (e.g. `./main` or
  an absolute path). There is also an **attach** config that lets you pick a running
  process by PID.
- Optimizations (`-O2`) inline and reorder code; step debugging is far more useful with
  `-O0`.

### TypeScript / JavaScript (Node)

- **Adapter:** `js-debug-adapter` / `pwa-node` (installed).
- **Start:** open a `.ts`/`.js` file, `<leader>dc`, pick **"Launch file"** to run the
  current file under Node, or **"Attach"** to attach to a running Node process (pick by
  PID). Works for `.jsx`/`.tsx` too.
- For TypeScript, either run through a loader (e.g. `tsx`, `ts-node`) or debug the
  compiled `.js` with a sourcemap. A `.vscode/launch.json` with a `runtimeExecutable`
  is the cleanest way for real projects (see [launch.json](#project-launchjson)).

### Angular / browser JavaScript

- **Adapter:** `chrome` (present, backed by `js-debug-adapter`). LazyVim only auto-defines
  **node** launch configs, not browser ones, so browser debugging needs a project
  `launch.json`.
- Use **`"type": "chrome"`** — it is mapped to the ts/js filetypes, so it appears in the
  `<leader>dc` picker for `.ts`/`.js` buffers. (`"pwa-chrome"` is *not* filetype-mapped
  and would not show up.)
- **Steps:**
  1. Serve the app: `ng serve` (Angular defaults to `http://localhost:4200`).
  2. Create `.vscode/launch.json` in the project root:
     ```json
     {
       "version": "0.2.0",
       "configurations": [
         {
           "type": "chrome",
           "request": "launch",
           "name": "Debug Angular in Chrome",
           "url": "http://localhost:4200",
           "webRoot": "${workspaceFolder}"
         }
       ]
     }
     ```
  3. `dap.core` reads `launch.json` automatically. `<leader>dc` → pick
     "Debug Angular in Chrome". Set breakpoints in your `.ts` components.

### PHP (Xdebug)

- **Adapter:** `php-debug-adapter` (installed). Config: **"PHP: Listen for Xdebug"** on
  port **9003**.
- PHP debugging is **reverse**: Neovim listens; your PHP runtime (with Xdebug) connects
  back when a request runs. You must install and configure Xdebug on the PHP side —
  this is external to Neovim.
- **Install + configure Xdebug:**
  1. Install: `pecl install xdebug` (or your distro/Homebrew package). Verify with
     `php -v` (it should mention Xdebug) or `php -m | grep -i xdebug`.
  2. Add to `php.ini` (find it with `php --ini`):
     ```ini
     zend_extension=xdebug
     xdebug.mode=debug
     xdebug.start_with_request=yes
     xdebug.client_port=9003
     xdebug.client_host=127.0.0.1
     ```
     `xdebug.mode=debug` enables step debugging; `client_port=9003` is the Xdebug 3
     default (matches the nvim config); `start_with_request=yes` triggers a debug
     connection on every request (use `trigger` + a browser extension if you want it
     opt-in).
- **Start a session:**
  1. In Neovim, open the `.php` file, set a breakpoint (`<leader>db`), then `<leader>dc`
     → pick **"PHP: Listen for Xdebug"**. Neovim is now listening on 9003.
  2. Run your PHP code so Xdebug connects: hit the URL in a browser, or run
     `php your_script.php` on the CLI, or trigger the PHPUnit/Pest test.
  3. Execution stops at your breakpoint.
- **Remote / Docker:** if PHP runs in a container or another host, add `pathMappings` to
  a `launch.json` config mapping the server path to your local path. Not needed for
  local same-filesystem debugging.

### Lua (this config / plugins)

- **Adapter:** `nlua` via `one-small-step-for-vimkind` (osv). Use the **attach flow** — it
  is the working, verified path and is what you want for debugging this config live.
- **Debug a live Neovim (attach flow):**
  1. In the Neovim instance you want to debug, start the osv server:
     `:lua require("osv").launch({ port = 8086 })`
  2. In a second Neovim, open the Lua file, set a breakpoint, `<leader>dc` → pick
     **"Attach to running Neovim instance (port = 8086)"**.
  3. Trigger the code in the first instance; the second stops at the breakpoint.
- **Caveat — the "Run this file" config is currently broken.** It calls
  `require("osv").run_this()`, which the installed osv version has removed (the field is
  `nil`), so starting that config errors. This is upstream API drift in LazyVim's
  `dap.nlua` extra, not this config. Use the attach flow above; to debug a standalone
  script, open it in the instance where you start the osv server.

## Project launch.json

`dap.core` reads `.vscode/launch.json` from the project root (VS Code format, comments
allowed). Any configurations there appear in the `<leader>dc` picker for the matching
filetype. This is the portable way to define per-project debug setups (program paths,
env vars, args, browser URLs) and share them with teammates using VS Code.

## Installation

Adapters are Mason packages. They install automatically, but you can manage them by hand.

- **Check what's installed:** `:Mason` (search for the adapter), or `:checkhealth dap`.
- **Install manually:** `:MasonInstall codelldb js-debug-adapter php-debug-adapter`.
- **Auto-install:** these are ensured on startup — `codelldb` (rust/clangd extras),
  `js-debug-adapter` (typescript extra), `php-debug-adapter` (`lua/langs/dap.lua`).
  `mason-nvim-dap` also installs adapters on demand for any configured language.

Current adapter → language map:

| Mason package | Adapter name(s) | Languages |
|-|-|-|
| `codelldb` | `codelldb` | Rust, C, C++ |
| `js-debug-adapter` | `pwa-node`, `pwa-chrome`, `pwa-msedge` | TypeScript, JavaScript, browser |
| `php-debug-adapter` | `php` | PHP |
| (bundled plugin) | `nlua` | Lua |

On a fresh machine, the first launch installs missing adapters in the background. If a
debug config is missing right after enabling, wait for Mason to finish (watch `:Mason`)
or restart Neovim.

## Adding a language

Most languages are a one-liner because LazyVim extras carry the DAP wiring.

1. **Enable the language extra** with `:LazyExtras` (e.g. `lang.python`, `lang.go`).
   If the extra has DAP support (Python → `debugpy`, Go → `delve`), it activates
   automatically because `dap.core` is already on.
2. **Confirm the adapter installs.** Most extras add it to Mason's `ensure_installed`.
   If not, either `:MasonInstall <adapter>` once, or add it in `lua/langs/dap.lua`:
   ```lua
   {
     "mason-org/mason.nvim",
     opts = { ensure_installed = { "debugpy" } },
   },
   ```
3. **Add a launch config only if the extra defines an adapter but no config** (PHP was
   this case). Either rely on `mason-nvim-dap`'s built-in config (it ships defaults for
   many adapters) or add one:
   ```lua
   {
     "mfussenegger/nvim-dap",
     optional = true,
     opts = function()
       local dap = require("dap")
       dap.configurations.python = dap.configurations.python or {}
       table.insert(dap.configurations.python, {
         type = "python",
         request = "launch",
         name = "Launch file",
         program = "${file}",
       })
     end,
   },
   ```

For a language with **no** LazyVim extra, define both the adapter and configurations in
a `lua/langs/<lang>.lua` file targeting `mfussenegger/nvim-dap` with `optional = true`.
See the [nvim-dap wiki](https://codeberg.org/mfussenegger/nvim-dap/wiki/Debug-Adapter-installation)
for adapter snippets.

## Troubleshooting

| Symptom | Cause / fix |
|-|-|
| `<leader>dc` does nothing / no configs | Adapter not installed yet. Check `:Mason`, run `:MasonInstall <adapter>`, restart. |
| "No configuration found for `<ft>`" | Language extra not enabled, or filetype unsupported. Enable the lang extra, or add a config (see above). |
| Rust `<leader>dr` opens the REPL | You're not in a `.rs` buffer, or rustaceanvim hasn't attached. Open a Rust file in a Cargo project. |
| C/C++ stops in the wrong place / can't see variables | Built without `-g` or with optimizations. Rebuild `-g -O0`. |
| PHP never hits the breakpoint | Xdebug not installed/enabled, wrong port, or `start_with_request` off. Verify `php -m | grep xdebug`, check `xdebug.client_port=9003`, confirm Neovim is listening (started the "Listen for Xdebug" config) before triggering the request. |
| Node "cannot find module" | Debugging `.ts` directly without a loader. Use `tsx`/`ts-node` or debug compiled JS with sourcemaps. |
| dap-ui won't close with `q` | `q` is remapped to a no-op globally in this config. Use `<leader>du` to toggle the UI. |
| Health check | `:checkhealth dap` reports adapter status and common misconfigurations. |

## Design notes

Decisions behind this setup, for future reference:

- **Extras enabled via `import` in `lua/config/lazy.lua`**, not by editing `lazyvim.json`
  (the config forbids hand-editing that file). Trade-off: `:LazyExtras` won't show
  `dap.core`/`dap.nlua` as ticked, but they are fully active. To migrate them into the
  `:LazyExtras`-managed list later, toggle them there and remove the two imports.
- **Only PHP needed a local file.** Rust, C/C++, and TypeScript get adapters *and*
  launch configs from their LazyVim extras for free. LazyVim's PHP extra defines the
  adapter but neither installs it nor gives it a config.
- **PHP config is not defined locally.** `lua/langs/dap.lua` only installs the adapter.
  Once installed, `mason-nvim-dap` supplies an identical "PHP: Listen for Xdebug" config
  automatically, so defining our own would create a duplicate entry in the picker.
- **Extra configs for `swift`/`zig` and multiple `c`/`cpp` entries** appear because
  `mason-nvim-dap` maps the installed `codelldb` to those filetypes. Harmless — unused
  languages are simply never triggered.
