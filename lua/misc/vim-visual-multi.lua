return {
  "mg979/vim-visual-multi",
  lazy = false,
  config = function()
    -- Keep default mappings
    vim.g.VM_default_mappings = 1

    -- Selectively disable only the conflicting mappings
    vim.g.VM_maps = {
      -- Disable the conflicting mappings by setting them to empty strings
      ["Goto Prev"] = "",
      ["Goto Next"] = "",

      -- All other default mappings will be preserved
    }
  end,
}
