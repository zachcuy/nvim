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

          -- <leader>fo → open the directory oil is currently showing in Finder
          ["<leader>fo"] = {
            desc = "Open current directory in Finder",
            callback = function()
              local dir = require("oil").get_current_dir()

              if not dir then
                vim.notify("oil: could not resolve current directory", vim.log.levels.WARN)
                return
              end

              vim.fn.jobstart({ "open", dir }, { detach = true })
              vim.notify("Opened in Finder: " .. dir, vim.log.levels.INFO)
            end,
          },

          -- gy → copy absolute path of current oil directory to clipboard
          gy = {
            desc = "oil: Copy current directory path",
            callback = function()
              local dir = require("oil").get_current_dir()

              if not dir then
                vim.notify("oil: could not resolve current directory", vim.log.levels.WARN)
                return
              end

              vim.fn.setreg("+", dir)
              vim.notify("Copied: " .. dir, vim.log.levels.INFO)
            end,
          },
        },
      })

      -- Remove a file's buffer when oil deletes the file. Otherwise the buffer
      -- lingers pointing at a missing path, and returning to it (when oil
      -- closes) makes Neovim's deleted-file handling freeze the UI for about a
      -- second each time it is triggered.
      local function canonical_path(p)
        -- Resolve symlinks via the parent dir (the file itself is already gone)
        -- so that /var/... and /private/var/... compare as equal.
        local dir = vim.fn.fnamemodify(p, ":h")
        local base = vim.fn.fnamemodify(p, ":t")
        local real_dir = vim.uv.fs_realpath(dir)
        if real_dir then
          return vim.fs.normalize(real_dir) .. "/" .. base
        end
        return vim.fs.normalize(p)
      end

      vim.api.nvim_create_autocmd("User", {
        pattern = "OilActionsPost",
        callback = function(args)
          if args.data.err then
            return
          end
          local oil_util = require("oil.util")
          local oil_fs = require("oil.fs")
          for _, action in ipairs(args.data.actions) do
            if action.type == "delete" then
              local _, path = oil_util.parse_url(action.url)
              if path then
                local target = canonical_path(oil_fs.posix_to_os_path(path))
                for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
                  local name = vim.api.nvim_buf_get_name(bufnr)
                  -- Skip unnamed and modified buffers (never discard unsaved work).
                  if name ~= "" and not vim.bo[bufnr].modified and canonical_path(name) == target then
                    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
                  end
                end
              end
            end
          end
        end,
      })
    end,
  },
}
