---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  dependencies = {
    { "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" },
  },
  opts = {
    ensure_installed = {
      "lua",
      "vim",
      "go",
      "gomod",
      "gosum",
      "gowork",
      "java",
      "json",
      "yaml",
    },
    auto_install = false,
    textobjects = {
      -- AstroNvim's legacy textobject engine is incompatible with Neovim 0.12.
      -- Query files remain available; mappings use lua/semantic_textobjects.lua.
      select = { enable = false },
      move = { enable = false },
      swap = { enable = false },
    },
  },
}
