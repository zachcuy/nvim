-- Configure Flash

return {
  "folke/flash.nvim",
  event = "VeryLazy",
  vscode = true,
  ---@type Flash.Config
  opts = {},
  -- stylua: ignore
  keys = {
    -- { "z", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
    -- { "Z", mode = { "n", "x", "o" }, function() require("flash").jump({ reverse = true }) end, desc = "Flash" },
  },
}
