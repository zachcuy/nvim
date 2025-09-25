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
    {
      "<leader><space>",
      function()
        require("fzf-lua").files({ cwd = vim.fn.getcwd() })
      end,
      desc = "Find Files (cwd)",
    },
  },
}
