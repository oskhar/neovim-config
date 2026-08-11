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
    servers = { "gopls", "jdtls", "spring_boot_ls", "html", "sqls" },
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
        -- Load Mason's Lombok agent so JDTLS understands generated constructors,
        -- getters, setters, and other Lombok-generated members.
        cmd = {
          "jdtls",
          "--jvm-arg=-Xms128m",
          "--jvm-arg=-Xmx768m",
          "--jvm-arg=-javaagent:" .. vim.fn.stdpath "data" .. "/mason/share/jdtls/lombok.jar",
        },
        settings = {
          java = {
            maxConcurrentBuilds = 1,
            completion = {
              favoriteStaticMembers = {
                "org.junit.jupiter.api.Assertions.*",
                "org.mockito.Mockito.*",
                "java.util.Objects.requireNonNull",
                "org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*",
                "org.springframework.test.web.servlet.result.MockMvcResultHandlers.*",
                "org.springframework.test.web.servlet.result.MockMvcResultMatchers.*",
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
      spring_boot_ls = {
        cmd = {
          "java",
          "-Xmx768m",
          "-Dsts.lsp.client=vscode",
          "-Dspring.main.web-application-type=NONE",
          "-Dspring.config.location=classpath:/application.properties",
          "-Djdk.util.zip.disableZip64ExtraFieldValidation=true",
          "-jar",
          vim.fn.stdpath "data"
            .. "/mason/packages/vscode-spring-boot-tools/extension/language-server/"
            .. "spring-boot-language-server-2.2.0-SNAPSHOT-exec.jar",
        },
        filetypes = { "jproperties" },
        root_markers = { "pom.xml", "mvnw", "gradlew", "build.gradle", "build.gradle.kts", ".git" },
        get_language_id = function(_, _) return "spring-boot-properties" end,
        init_options = {
          enableJdtClasspath = false,
        },
        capabilities = {
          workspace = {
            executeCommand = { dynamicRegistration = true },
          },
        },
      },
      sqls = {
        filetypes = { "sql", "mysql", "plsql" },
        settings = {
          sqls = {
            connections = {},
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
      -- sqls' formatter can rewrite MariaDB/MySQL DDL and statement
      -- boundaries. Keep its completion and diagnostics, but never let it
      -- modify SQL buffers during save or a generic LSP format request.
      if client.name == "sqls" then
        client.server_capabilities.documentFormattingProvider = false
        client.server_capabilities.documentRangeFormattingProvider = false
      end
      if vim.b[bufnr].large_buf then client.server_capabilities.semanticTokensProvider = nil end
    end,
  },
}
