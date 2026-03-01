return {
  {
    "stevearc/oil.nvim",
    ---@module 'oil'
    ---@type oil.SetupOpts

    -- optional dependencies
    dependencies = { { "nvim-mini/mini.icons", opts = {} } },

    -- config
    config = function()
      local oil = require("oil")

      -- Register a custom column to show the file type (e.g., markdown, c++)
      require("oil.columns").register("filetype", {
        render = function(entry)
          local name = entry[require("oil.constants").FIELD_NAME] or ""
          local type = entry[require("oil.constants").FIELD_TYPE]
          if type == "directory" then
            return "dir"
          elseif type == "link" then
            return "link"
          end

          -- Try to detect Neovim filetype, fallback to file extension
          local ft = vim.filetype.match({ filename = name })
          if not ft then
            local ext = name:match("%.([^.]+)$")
            ft = ext or "file"
          end

          -- Custom overrides for specific extensions/filetypes
          local overrides = {
            cpp = "c++",
            md = "markdown",
            js = "javascript",
            ts = "typescript",
            py = "python",
            rs = "rust",
            sh = "bash"
          }
          return overrides[ft] or ft
        end,
        parse = function(line)
          return line:match("^(%S+)%s+(.*)$")
        end
      })

      oil.setup({
        -- Add the custom filetype column and mtime for last modified
        columns = {
          "icon",
          { "filetype", highlight = "Comment" },
          -- { "size", highlight = "String" }, -- Optional: un-comment to show file size
          { "mtime", highlight = "Number" },
        },
        delete_to_trash = true,

        view_options = {
          show_hidden = true,
          natural_order = true,
        },
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
