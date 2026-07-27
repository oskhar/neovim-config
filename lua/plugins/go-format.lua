return {
  "stevearc/conform.nvim",
  dependencies = { "williamboman/mason.nvim" },
  opts = {
    formatters_by_ft = {
      go = { "goimports", "gofumpt" },
      java = { "google-java-format" },
    },
    format_on_save = {
      timeout_ms = 2000,
      lsp_format = "fallback",
    },
  },
}
