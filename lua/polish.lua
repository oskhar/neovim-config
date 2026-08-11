-- This will run last in the setup process.
-- This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here
require("java_template").setup()

-- AstroLSP only knows built-in lspconfig servers during its lazy setup.
-- Enable the custom Spring Boot properties server explicitly.
vim.lsp.enable "spring_boot_ls"
