---@type LazySpec
return {
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      -- Completion can run immediately on FileType=sql and calls db#resolve.
      -- Load the small core plugin at startup so that function always exists.
      { "tpope/vim-dadbod", lazy = false },
      {
        "kristijanhusak/vim-dadbod-completion",
        ft = { "sql", "mysql", "plsql" },
        lazy = true,
      },
    },
    cmd = {
      "DBUI",
      "DBUIToggle",
      "DBUIAddConnection",
      "DBUIFindBuffer",
      "DBUIRenameBuffer",
      "DBUILastQueryInfo",
    },
    keys = {
      { "<Leader>D", desc = "Database" },
      { "<Leader>Du", "<Cmd>DBUIToggle<CR>", desc = "Toggle database UI" },
      {
        "<Leader>Da",
        function() require("database").setup_connection() end,
        desc = "Add simple database connection",
      },
      { "<Leader>DA", "<Cmd>DBUIAddConnection<CR>", desc = "Add connection from URL" },
      { "<Leader>Df", "<Cmd>DBUIFindBuffer<CR>", desc = "Find database query buffer" },
      {
        "<Leader>Ds",
        function() require("database").select_connection() end,
        desc = "Select connection for current buffer",
        ft = { "sql", "mysql", "plsql" },
      },
      {
        "<Leader>Dt",
        function() require("database").test_connection() end,
        desc = "Test current database connection",
        ft = { "sql", "mysql", "plsql" },
      },
      {
        "<Leader>Dl",
        function() require("database").execute_line() end,
        desc = "Execute current SQL line",
        ft = { "sql", "mysql", "plsql" },
      },
      {
        "<Leader>Db",
        function() require("database").execute_buffer() end,
        desc = "Execute current SQL file",
        ft = { "sql", "mysql", "plsql" },
      },
      {
        "<Leader>De",
        "<Esc><Cmd>lua require('database').execute_selection()<CR>",
        mode = "v",
        desc = "Execute selected SQL",
        ft = { "sql", "mysql", "plsql" },
      },
    },
    init = function()
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_execute_on_save = 0
      vim.g.db_ui_show_database_icon = 1
      vim.g.db_ui_win_position = "left"
      vim.g.db_ui_winwidth = 40
      vim.g.db_ui_save_location = vim.fn.stdpath "data" .. "/db_ui"
      require("database").migrate_mariadb_client()
      require("database").setup_auto_restore()
    end,
  },
}
