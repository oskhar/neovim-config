return {
  "rebelot/heirline.nvim",
  opts = function(_, opts)
    local application = {
      provider = function() return " " .. require("project_tasks").status().label .. " " end,
      hl = function()
        local state = require("project_tasks").status().state
        if state == "running" then return { fg = "green", bold = true } end
        if state == "failed" then return { fg = "red", bold = true } end
        if state == "stopping" then return { fg = "yellow", bold = true } end
        return { fg = "grey" }
      end,
      update = { "User", pattern = "ProjectTaskStatus" },
    }

    -- Place the application status immediately before the navigation section.
    table.insert(opts.statusline, math.max(1, #opts.statusline - 1), application)
  end,
}
