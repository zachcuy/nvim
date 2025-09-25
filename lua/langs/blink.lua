return {
  "saghen/blink.cmp",
  opts = {
    keymap = {
      preset = "default",
      ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
      ["<C-k>"] = { "show_signature", "hide_signature", "fallback" },
      ["<C-e>"] = { "hide", "fallback" },
      ["<C-f>"] = { "select_and_accept", "fallback" },

      ["<Up>"] = { "select_prev", "fallback" },
      ["<Down>"] = { "select_next", "fallback" },
      ["<C-n>"] = { "select_prev", "fallback" },
      ["<C-m>"] = { "select_next", "fallback" },

      ["<C-.>"] = { "scroll_documentation_up", "fallback" },
      ["<C-,>"] = { "scroll_documentation_down", "fallback" },

      -- disable keymaps that preset may have set
      -- falling back so that it uses whatever is in lazyvim/neovim's keymaps
      ["<CR>"] = { "fallback" },
      ["<Tab>"] = { "fallback" },
      ["<S-Tab>"] = { "fallback" },
      ["<C-p>"] = { "fallback" },
      ["<C-b>"] = { "fallback" },
    },
  },
}
