return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "macchiato", -- latte | frappe | macchiato | mocha
      integrations = {
        treesitter = true,
        native_lsp = {
          enabled = true,
        },
        telescope = true,
        cmp = true,
        gitsigns = true,
        nvimtree = true,
      },
    },
  },
}
