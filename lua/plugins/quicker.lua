return {
  "stevearc/quicker.nvim",
  ft = "qf",
  keys = {
    {
      "<Leader>qo",
      function() require("quicker").toggle() end,
      desc = "Toggle test/errors quickfix",
    },
  },
  opts = {
    opts = {
      number = true,
      relativenumber = false,
      signcolumn = "auto",
      wrap = false,
    },
    edit = {
      enabled = true,
      autosave = "unmodified",
    },
  },
}
