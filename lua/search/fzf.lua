return {
  "ibhagwan/fzf-lua",
  keys = {
    {
      "<leader>/",
      function()
        LazyVim.pick("live_grep", { root = false })()
      end,
      desc = "Grep (cwd)",
    },
  },
}
