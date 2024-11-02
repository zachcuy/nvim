return {
  {
    "stevearc/oil.nvim",
    ---@module 'oil'
    ---@type oil.SetupOpts

    -- optional dependencies
    dependencies = { { "echasnovski/mini.icons", opts = {} } },

    -- config
    config = function()
      local oil = require("oil")
      oil.setup({
        keymaps = {
          -- change ctrl + s keymap to save changes
          ["<C-s>"] = {
            callback = function()
              vim.cmd("write") -- Saves the current buffer
            end,
            desc = "Save current buffer",
          },

          -- disable open in horizontal split window, open in new tab
          ["<C-h>"] = "<Nop>",
          ["<C-t>"] = "<Nop>",

          -- add keymap for q to close the oil buffer
          ["q"] = "actions.close",

          -- create a new mapping, gs, to search and replace in the current directory
          gs = {
            callback = function()
              -- get the current directory
              local prefills = { paths = oil.get_current_dir() }

              local grug_far = require("grug-far")
              -- instance check
              if not grug_far.has_instance("explorer") then
                grug_far.open({
                  instanceName = "explorer",
                  prefills = prefills,
                  staticTitle = "Find and Replace from Explorer",
                })
              else
                grug_far.open_instance("explorer")
                -- updating the prefills without clearing the search and other fields
                grug_far.update_instance_prefills("explorer", prefills, false)
              end
            end,
            desc = "oil: Search in directory",
          },
        },
      })
    end,
  },
}
