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
      "<leader>`",
      function()
        require("fzf-lua").live_grep({
          cwd = vim.fn.getcwd(),
          rg_opts = "--fixed-strings --column --line-number --no-heading --color=always --smart-case",
        })
      end,
      desc = "Grep Literal (cwd)",
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
