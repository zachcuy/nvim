-- PHP debugging. LazyVim's PHP extra wires up dap.adapters.php but never adds the
-- adapter to Mason's install list, so it never gets installed. Add it here. Once
-- installed, mason-nvim-dap supplies the "PHP: Listen for Xdebug" launch config
-- automatically. Rust, C/C++, and TS/JS need nothing extra -- their adapters and
-- launch configs ship with the matching lang extras and light up once dap.core
-- is enabled.
return {
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "php-debug-adapter" } },
  },
}
