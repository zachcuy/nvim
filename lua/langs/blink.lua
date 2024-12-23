return {
  "saghen/blink.cmp",
  opts = {
    keymap = {
      ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
      ["<C-e>"] = { "hide" },
      ["<C-f>"] = { "select_and_accept" },

      ["<C-n>"] = { "select_prev", "fallback" },
      ["<C-m>"] = { "select_next", "fallback" },

      ["<C-.>"] = { "scroll_documentation_up", "fallback" },
      ["<C-,>"] = { "scroll_documentation_down", "fallback" },
    },
  },
}
