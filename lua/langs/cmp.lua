local M = {
  "hrsh7th/nvim-cmp",
  event = "InsertEnter",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-calc",
    "hrsh7th/cmp-emoji",
    "hrsh7th/cmp-nvim-lua",
    "hrsh7th/cmp-path",
    "f3fora/cmp-spell",
    "lukas-reineke/cmp-rg",

    -- snippets
    "L3MON4D3/LuaSnip",
    {
      "rafamadriz/friendly-snippets",
      config = function()
        require("luasnip.loaders.from_vscode").lazy_load()
      end,
    },
    "saadparwaiz1/cmp_luasnip",

    -- command line
    "hrsh7th/cmp-cmdline",
    -- "dmitmel/cmp-cmdline-history",

    -- search
    "hrsh7th/cmp-buffer",
  },
}

M.config = function()
  local cmp = require("cmp")
  local compare = require("cmp.config.compare")
  local luasnip = require("luasnip")

  cmp.setup({
    completion = {
      completeopt = "menu,menuone,noinsert",
    },

    mapping = {
      ["<C-e>"] = cmp.mapping.abort(),

      ["<C-j>"] = cmp.mapping.scroll_docs(4),
      ["<C-k>"] = cmp.mapping.scroll_docs(-4),

      ["<C-b>"] = cmp.mapping.complete({ reason = cmp.ContextReason.Auto }),

      ["<C-m>"] = cmp.mapping(cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }), { "i" }),
      ["<C-n>"] = cmp.mapping(cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }), { "i" }),

      ["<C-f>"] = cmp.mapping(cmp.mapping.confirm(), { "i", "c" }),

      ["<Tab>"] = cmp.mapping(function(fallback)
        if luasnip.expand_or_locally_jumpable() then
          luasnip.expand_or_jump()
        else
          fallback()
        end
      end, { "i", "s" }),

      ["<S-Tab>"] = cmp.mapping(function(fallback)
        if luasnip.locally_jumpable(-1) then
          luasnip.jump(-1)
        else
          fallback()
        end
      end, { "i", "s" }),
    },

    sources = {
      { name = "nvim_lsp" },
      { name = "nvim_lsp_signature_help" },
      { name = "luasnip" },
      { name = "path" },
      { name = "nvim_lua" },
      { name = "calc" },
      { name = "emoji" },
      { name = "spell", keyword_length = 4 },
      { name = "rg", dup = 0 },
    },

    snippet = {
      expand = function(args)
        require("luasnip").lsp_expand(args.body)
      end,
    },

    window = {
      completion = cmp.config.window.bordered({
        col_offset = -3,
        side_padding = 0,
        winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
      }),
      documentation = cmp.config.window.bordered({
        winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
      }),
    },

    sorting = { ---@diagnostic disable-line: missing-fields
      comparators = {
        -- defaults: https://github.com/hrsh7th/nvim-cmp/blob/main/lua/cmp/config/default.lua#L67-L78
        -- compare functions https://github.com/hrsh7th/nvim-cmp/blob/main/lua/cmp/config/compare.lua
        compare.offset,
        compare.recently_used, -- higher
        compare.score,
        compare.kind, -- higher (prioritize snippets)
        compare.exact, -- lower
        compare.locality,
        compare.length,
        compare.order,
      },
    },

    view = {
      entries = { name = "custom", selection_order = "near_cursor" },
    },

    experimental = {
      ghost_text = true,
    },
  })

  cmp.setup.cmdline(":", {
    mapping = cmp.mapping.preset.cmdline({}),
    sources = {
      { name = "cmdline" },
      { name = "cmdline_history" },
      { name = "path" },
    },
  })

  cmp.setup.cmdline("/", {
    mapping = cmp.mapping.preset.cmdline({}),
    sources = {
      { name = "buffer" },
    },
  })
end

return M
