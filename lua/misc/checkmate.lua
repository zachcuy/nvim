-- Shift the @done date of the todo under the cursor by `days` (multiplied by count)
local function shift_done_date(days)
  local checkmate = require("checkmate")
  local todo = checkmate.get_todo()
  if not todo then
    return
  end
  local _, value = todo.get_metadata("done")
  local m, d, y = (value or ""):match("^(%d%d)/(%d%d)/(%d%d)$")
  if not m then
    vim.notify("No @done(mm/dd/yy) date on this todo", vim.log.levels.WARN)
    return
  end
  -- os.time rolls day overflow into the adjacent month and year
  local t = os.time({
    year = 2000 + tonumber(y),
    month = tonumber(m),
    day = tonumber(d) + days * vim.v.count1,
    hour = 12, -- noon avoids DST edge cases
  })
  checkmate.update_metadata("done", tostring(os.date("%m/%d/%y", t)))
end

return {
  "bngarren/checkmate.nvim",
  ft = "markdown",
  opts = {
    files = { "*.md" },
    enter_insert_after_new = false,
    log = {},
    smart_toggle = {
      enabled = false,
    },
    keys = {
      ["<leader>tt"] = {
        rhs = "<cmd>Checkmate toggle<CR>",
        desc = "Toggle todo item",
        modes = { "n", "v" },
      },
      ["<leader>tc"] = {
        rhs = "<cmd>Checkmate check<CR>",
        desc = "Set todo item as checked (done)",
        modes = { "n", "v" },
      },
      ["<leader>tu"] = {
        rhs = "<cmd>Checkmate uncheck<CR>",
        desc = "Set todo item as unchecked (not done)",
        modes = { "n", "v" },
      },
      ["<leader>t="] = {
        rhs = "<cmd>Checkmate cycle_next<CR>",
        desc = "Cycle todo item(s) to the next state",
        modes = { "n", "v" },
      },
      ["<leader>t-"] = {
        rhs = "<cmd>Checkmate cycle_previous<CR>",
        desc = "Cycle todo item(s) to the previous state",
        modes = { "n", "v" },
      },
      ["<leader>tn"] = {
        rhs = "<cmd>Checkmate create<CR>",
        desc = "Create todo item",
        modes = { "n", "v" },
      },
      ["<leader>tr"] = {
        rhs = "<cmd>Checkmate remove<CR>",
        desc = "Remove todo marker (convert to text)",
        modes = { "n", "v" },
      },
      ["<leader>tR"] = {
        rhs = "<cmd>Checkmate metadata remove_all<CR>",
        desc = "Remove all metadata from a todo item",
        modes = { "n", "v" },
      },
      ["<leader>tF"] = {
        rhs = "<cmd>Checkmate select_todo<CR>",
        desc = "Open a picker to select a todo from the current buffer",
        modes = { "n" },
      },
      ["<leader>tv"] = {
        rhs = "<cmd>Checkmate metadata select_value<CR>",
        desc = "Update the value of a metadata tag under the cursor",
        modes = { "n" },
      },
      ["<leader>t."] = {
        rhs = function()
          shift_done_date(1)
        end,
        desc = "Increment @done date by one day",
        modes = { "n" },
      },
      ["<leader>t,"] = {
        rhs = function()
          shift_done_date(-1)
        end,
        desc = "Decrement @done date by one day",
        modes = { "n" },
      },

      -- Custom states
      ["<leader>tx"] = {
        rhs = "<cmd>Checkmate toggle cancelled<CR>",
        desc = "Set todo: cancelled",
        modes = { "n", "v" },
      },
      ["<leader>th"] = {
        rhs = "<cmd>Checkmate toggle on_hold<CR>",
        desc = "Set todo: on hold",
        modes = { "n", "v" },
      },
    },
    todo_states = {
      -- Built-in states (cannot change markdown or type)
      -- unchecked = { marker = "□" },
      -- checked = { marker = "✔" },

      -- Custom states
      cancelled = {
        marker = "✗",
        markdown = "c", -- Saved as `- [c]`
        type = "complete", -- Counts as "done"
        order = 2,
      },
      on_hold = {
        marker = "⏸",
        markdown = "/", -- Saved as `- [/]`
        type = "inactive", -- Ignored in counts
        order = 100,
      },
    },
    style = {
      -- Cancelled: dim red item, nested content dimmed like completed
      CheckmateCancelledMarker = { fg = "#cc6666", bold = true },
      CheckmateCancelledMainContent = { fg = "#cc6666", strikethrough = true },
      CheckmateCancelledAdditionalContent = { link = "CheckmateCheckedAdditionalContent" },

      -- On-hold: pastel yellow item, nested content dimmed like completed
      CheckmateOnHoldMarker = { fg = "#f9e2af", bold = true },
      CheckmateOnHoldMainContent = { fg = "#f9e2af" },
      CheckmateOnHoldAdditionalContent = { link = "CheckmateCheckedAdditionalContent" },
    },
    metadata = {
      -- Example: A @done tag that also sets the todo item state when it is added and removed
      done = {
        aliases = { "completed", "finished" },
        style = { fg = "#96de7a" },
        get_value = function()
          return tostring(os.date("%m/%d/%y"))
        end,
        key = "<leader>td",
        on_add = function(todo)
          require("checkmate").set_todo_state(todo, "checked")
        end,
        on_remove = function(todo)
          require("checkmate").set_todo_state(todo, "unchecked")
        end,
        sort_order = 30,
      },
    },
  },
}
