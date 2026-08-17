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
          rg_opts = '--fixed-strings --column --line-number --no-heading --color=always --smart-case -g "!.git" -g "!.jj"',
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
  opts = function(_, opts)
    -- On macOS the Option key sends Alt, which tmux grabs before fzf sees it.
    -- Move the picker's Alt actions onto free Ctrl keys so they work here.
    -- Ctrl-g is avoided for the shared toggles: grep pickers already bind it to
    -- the regex/fuzzy search switch.
    local files = require("fzf-lua.config").defaults.actions.files
    files["ctrl-o"] = files["alt-i"] -- toggle .gitignore
    files["ctrl-y"] = files["alt-h"] -- toggle hidden files
    files["ctrl-l"] = files["alt-q"] -- send selection to quickfix
    files["ctrl-g"] = files["alt-f"] -- toggle follow symlinks (files picker only)
    files["alt-i"], files["alt-h"], files["alt-q"], files["alt-f"] = nil, nil, nil, nil

    -- LazyVim re-binds ignore/hidden per picker (files, grep) without marking them
    -- header = false, so those bindings are what the picker's header text shows.
    -- Mirror the Ctrl mapping here so the header stops advertising the old Alt keys.
    for _, picker in ipairs({ opts.files, opts.grep }) do
      if picker and picker.actions then
        picker.actions["ctrl-o"] = picker.actions["alt-i"]
        picker.actions["ctrl-y"] = picker.actions["alt-h"]
        picker.actions["alt-i"], picker.actions["alt-h"] = nil, nil
      end
    end
    -- Grep pickers search gitignored and hidden files by default (ctrl-o / ctrl-y toggle back).
    -- The .git/.jj globs stop --hidden from crawling VCS internals.
    opts.grep = opts.grep or {}
    opts.grep.no_ignore = true
    opts.grep.hidden = true
    opts.grep.rg_opts = '-g "!.git" -g "!.jj" ' .. require("fzf-lua.config").defaults.grep.rg_opts

    -- Files picker includes gitignored files too (hidden files are already on by default,
    -- and its fd_opts already exclude .git/.jj).
    opts.files = opts.files or {}
    opts.files.no_ignore = true

    -- Make the picker window bigger (LazyVim default is 0.8 x 0.8).
    opts.winopts = opts.winopts or {}
    opts.winopts.width = 0.90
    opts.winopts.height = 0.90
    return opts
  end,
}
