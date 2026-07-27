---@type LazySpec
return {
  -- Aerial currently calls an obsolete Treesitter node API on Neovim 0.12.
  -- Disabling it also avoids maintaining a second symbol-outline index.
  { "stevearc/aerial.nvim", enabled = false },
}
