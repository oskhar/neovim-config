---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      ensure_installed = {
        "lua-language-server",
        "gopls",
        "jdtls",
        "stylua",
        "goimports",
        "gofumpt",
        "google-java-format",
        "delve",
      },
      auto_update = false,
      run_on_start = false,
    },
  },
}
