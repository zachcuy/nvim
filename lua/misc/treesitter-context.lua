return {
  "nvim-treesitter/nvim-treesitter-context",
  enabled = true,
  opts = {
    max_lines = 3,       -- max lines the context window can show
    trim_scope = "outer", -- which context lines to discard: "inner" or "outer"
    mode = "cursor",     -- "cursor" = show context for cursor position
  },
}
