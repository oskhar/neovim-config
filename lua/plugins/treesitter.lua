---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  commit = "61df84986b4b4ec469ee745a182e433d49f8c27e",
  pin = false,
  lazy = false,
  dependencies = {
    {
      "nvim-treesitter/nvim-treesitter-textobjects",
      branch = "main",
      commit = "898ee307df58f854d11cd7edd06472574d48014e",
      pin = false,
    },
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
      "html",
      "properties",
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
  -- AstroNvim 5 still calls the removed `nvim-treesitter.configs` API.
  -- Configure the new Treesitter API directly until AstroNvim adopts it.
  config = function()
    local treesitter = require "nvim-treesitter"
    treesitter.setup {}

    local group = vim.api.nvim_create_augroup("treesitter_highlight", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "*",
      callback = function(args) pcall(vim.treesitter.start, args.buf) end,
      desc = "Enable Treesitter highlighting",
    })
  end,
}
