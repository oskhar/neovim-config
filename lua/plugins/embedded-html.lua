---@type LazySpec
return {
  {
    "jmbuhr/otter.nvim",
    ft = { "java" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      buffers = { set_filetype = true },
    },
    config = function(_, opts)
      local otter = require "otter"
      otter.setup(opts)

      local function activate_html()
        local bufnr = vim.api.nvim_get_current_buf()
        if vim.bo[bufnr].filetype == "java" and not require("otter.keeper").has_raft(bufnr) then
          otter.activate({ "html" }, true, true)
        end
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "java",
        callback = function() vim.schedule(activate_html) end,
        desc = "Enable HTML LSP in Java strings containing <html>",
      })

      -- The FileType event that lazy-loaded this plugin has already started.
      vim.schedule(activate_html)
    end,
  },
}
