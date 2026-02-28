return {
  {
    "lewis6991/gitsigns.nvim",
    opts = function(_, opts)
      local orig_on_attach = opts.on_attach
      opts.on_attach = function(bufnr)
        -- Disable GitSigns for markdown files
        if vim.bo[bufnr].filetype == "markdown" then
          return false
        end
        if orig_on_attach then
          orig_on_attach(bufnr)
        end
      end
    end,
  },
}
