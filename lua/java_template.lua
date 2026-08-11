local M = {}

local function package_from_path(path)
  path = path:gsub("\\", "/")

  -- A conventional Java source root ends in a directory named "java".
  local package_path = path:match "/src/[^/]+/java/(.+)/[^/]+%.java$"
    or path:match "/src/java/(.+)/[^/]+%.java$"

  if not package_path then return nil end
  return package_path:gsub("/", ".")
end

local function add_template(args)
  local buffer = args.buf
  local first_line = vim.api.nvim_buf_get_lines(buffer, 0, 1, false)[1]
  if vim.api.nvim_buf_line_count(buffer) ~= 1 or first_line ~= "" then return end

  local path = vim.api.nvim_buf_get_name(buffer)
  local class_name = vim.fn.fnamemodify(path, ":t:r")
  if not class_name:match "^[%a_$][%w_$]*$" then return end

  local package_name = package_from_path(path)
  local lines = {}

  if package_name then vim.list_extend(lines, { "package " .. package_name .. ";", "" }) end

  vim.list_extend(lines, {
    "public class " .. class_name .. " {",
    "    ",
    "}",
  })

  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { #lines - 1, 4 })
end

function M.setup()
  local group = vim.api.nvim_create_augroup("java_file_template", { clear = true })
  vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
    group = group,
    pattern = "*.java",
    callback = add_template,
    desc = "Create package and class declaration for new Java files",
  })
end

return M
