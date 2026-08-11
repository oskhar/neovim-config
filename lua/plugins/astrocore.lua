local function semantic_select(capture)
  return function() require("semantic_textobjects").select(capture) end
end

local function semantic_mappings()
  return {
    af = { semantic_select "function.outer", desc = "Around function/method" },
    ["if"] = { semantic_select "function.inner", desc = "Inside function/method" },
    ac = { semantic_select "class.outer", desc = "Around class" },
    ic = { semantic_select "class.inner", desc = "Inside class" },
    aa = { semantic_select "parameter.outer", desc = "Around argument" },
    ia = { semantic_select "parameter.inner", desc = "Inside argument" },
    ai = { semantic_select "conditional.outer", desc = "Around conditional" },
    ii = { semantic_select "conditional.inner", desc = "Inside conditional" },
    al = { semantic_select "loop.outer", desc = "Around loop" },
    il = { semantic_select "loop.inner", desc = "Inside loop" },
    aC = { semantic_select "comment.outer", desc = "Around comment" },
    iC = { semantic_select "comment.outer", desc = "Comment" },
  }
end

local function semantic_move(capture, forward)
  return function() require("semantic_textobjects").move(capture, forward) end
end

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    features = {
      -- Generated files and logs should not trigger expensive syntax/UI work.
      large_buf = { notify = false, size = 512 * 1024, lines = 20000, line_length = 1000 },
      autopairs = true,
      cmp = true,
      diagnostics = { virtual_text = true, virtual_lines = false },
      highlighturl = false,
      notifications = true,
    },
    diagnostics = {
      virtual_text = { spacing = 2, source = "if_many" },
      underline = true,
      severity_sort = true,
      update_in_insert = false,
    },
    options = {
      opt = {
        relativenumber = true,
        number = true,
        spell = false,
        signcolumn = "yes",
        wrap = true,
        linebreak = true,
        breakindent = true,
        updatetime = 300,
        timeoutlen = 400,
        undofile = true,
      },
    },
    mappings = {
      n = {
        ["<Leader>a"] = { desc = "Local AI" },
        ["<Leader>aa"] = {
          function() require("local_ai").ask() end,
          desc = "Ask offline AI about current buffer",
        },
        ["<Leader>t"] = { desc = "Test" },
        ["<Leader>tt"] = {
          function() require("project_tasks").test_file() end,
          desc = "Test current file/package",
        },
        ["<Leader>tT"] = {
          function() require("project_tasks").test_all() end,
          desc = "Test entire project",
        },
        ["<Leader>tb"] = {
          function() require("project_tasks").test_nearest() end,
          desc = "Test nearest to cursor",
        },
        ["<Leader>tf"] = {
          function() require("project_tasks").test_nearest_full() end,
          desc = "Test nearest with full log",
        },
        ["<Leader>r"] = { desc = "Run/Build" },
        ["<Leader>rr"] = {
          function() require("project_tasks").run() end,
          desc = "Run application",
        },
        ["<Leader>rs"] = {
          function() require("project_tasks").stop() end,
          desc = "Stop application",
        },
        ["<Leader>ro"] = {
          function() require("project_tasks").toggle_log() end,
          desc = "Toggle application log",
        },
        ["<Leader>j"] = { desc = "Java" },
        ["<Leader>jc"] = {
          function() require("java_cache").clear_project() end,
          desc = "Clear current project JDTLS cache",
        },
        ["<Leader>jt"] = {
          function() require("java_test_generator").open_or_generate() end,
          desc = "Open or generate Spring Boot test for current Java file",
        },
        ["<Leader>rb"] = {
          function() require("project_tasks").build() end,
          desc = "Build project",
        },
        ["<Leader>rl"] = {
          function() require("project_tasks").run_last() end,
          desc = "Repeat last project task",
        },
        ["]m"] = { semantic_move("function.outer", true), desc = "Next method/function" },
        ["[m"] = { semantic_move("function.outer", false), desc = "Previous method/function" },
        ["]c"] = { semantic_move("class.outer", true), desc = "Next class" },
        ["[c"] = { semantic_move("class.outer", false), desc = "Previous class" },
        ["<Leader>ga"] = {
          function() require("git_tasks").add_current() end,
          desc = "Git add current file",
        },
        ["<Leader>gA"] = {
          function() require("git_tasks").add_all() end,
          desc = "Git add all changes",
        },
        ["<Leader>gc"] = {
          function() require("git_tasks").commit() end,
          desc = "Git commit (Commitizen aware)",
        },
        ["<Leader>gP"] = {
          function() require("git_tasks").push() end,
          desc = "Git push",
        },
      },
      v = {
        ["<Leader>aa"] = {
          function() require("local_ai").ask_visual() end,
          desc = "Ask offline AI about selection",
        },
      },
      t = {
        ["<Leader>ro"] = {
          function() require("project_tasks").toggle_log() end,
          desc = "Hide application log",
        },
      },
      o = semantic_mappings(),
      x = semantic_mappings(),
    },
  },
}
