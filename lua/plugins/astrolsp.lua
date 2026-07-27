---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    features = {
      codelens = false,
      inlay_hints = false,
      semantic_tokens = true,
    },
    formatting = {
      format_on_save = {
        enabled = true,
        allow_filetypes = { "go", "java", "lua" },
      },
      timeout_ms = 2000,
    },
    servers = { "gopls", "jdtls" },
    config = {
      gopls = {
        settings = {
          gopls = {
            gofumpt = true,
            usePlaceholders = true,
            completeFunctionCalls = true,
            directoryFilters = { "-**/.git", "-**/node_modules", "-**/vendor" },
            diagnosticsTrigger = "Save",
            analyses = {
              nilness = true,
              shadow = true,
              unusedparams = true,
              unusedwrite = true,
            },
            codelenses = {
              generate = false,
              regenerate_cgo = false,
              run_govulncheck = false,
              tidy = false,
              upgrade_dependency = false,
              vendor = false,
            },
            vulncheck = "Off",
          },
        },
      },
      jdtls = {
        -- Mason's wrapper forwards these arguments to the JVM.
        cmd = { "jdtls", "--jvm-arg=-Xms128m", "--jvm-arg=-Xmx768m" },
        settings = {
          java = {
            maxConcurrentBuilds = 1,
            completion = {
              favoriteStaticMembers = {
                "org.junit.jupiter.api.Assertions.*",
                "org.mockito.Mockito.*",
                "java.util.Objects.requireNonNull",
              },
              filteredTypes = {
                "com.sun.*",
                "sun.*",
                "jdk.*",
                "org.graalvm.*",
              },
            },
            configuration = { updateBuildConfiguration = "interactive" },
            import = {
              gradle = { enabled = true },
              maven = { enabled = true },
              exclusions = { "**/node_modules/**", "**/.git/**", "**/vendor/**" },
            },
            referencesCodeLens = { enabled = false },
            implementationsCodeLens = { enabled = false },
            signatureHelp = { enabled = true },
          },
        },
      },
    },
    autocmds = {},
    mappings = {
      n = {
        gD = {
          function() vim.lsp.buf.declaration() end,
          desc = "Declaration of current symbol",
          cond = "textDocument/declaration",
        },
      },
    },
    on_attach = function(client, bufnr)
      if vim.b[bufnr].large_buf then client.server_capabilities.semanticTokensProvider = nil end
    end,
  },
}
