return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "mocha", -- latte | frappe | macchiato | mocha
      integrations = {
        treesitter = true,
        native_lsp = {
          enabled = true,
        },
        telescope = true,
        cmp = true,
        gitsigns = true,
        neo_tree = true,
      },
    },
  },
}
