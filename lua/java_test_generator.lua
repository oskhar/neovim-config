local M = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Java Test Generator" })
end

local function read_package(bufnr)
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    local package_name = line:match "^%s*package%s+([%w_%.]+)%s*;"
    if package_name then return package_name end
  end
end

local function test_path(source_path, class_name)
  local test_file = class_name .. "Test.java"
  local marker = "/src/main/java/"
  local start = source_path:find(marker, 1, true)

  if start then
    local project_root = source_path:sub(1, start - 1)
    local relative_dir = vim.fs.dirname(source_path:sub(start + #marker))
    return vim.fs.joinpath(project_root, "src", "test", "java", relative_dir, test_file)
  end

  return vim.fs.joinpath(vim.fs.dirname(source_path), test_file)
end

function M.open_or_generate()
  local bufnr = vim.api.nvim_get_current_buf()
  local source_path = vim.api.nvim_buf_get_name(bufnr)

  if vim.bo[bufnr].filetype ~= "java" or source_path == "" or not source_path:match "%.java$" then
    notify("Jalankan shortcut ini dari file Java yang sudah disimpan.", vim.log.levels.WARN)
    return
  end

  local class_name = vim.fs.basename(source_path):gsub("%.java$", "")
  if class_name:match "Test$" then
    notify("File aktif sudah merupakan class test.", vim.log.levels.WARN)
    return
  end

  local destination = test_path(source_path, class_name)
  local destination_stat = vim.uv.fs_stat(destination)
  if destination_stat and destination_stat.type == "file" then
    vim.cmd.edit(vim.fn.fnameescape(destination))
    return
  end

  local lines = {}
  local package_name = read_package(bufnr)
  if package_name then
    vim.list_extend(lines, { "package " .. package_name .. ";", "" })
  end

  vim.list_extend(lines, {
    "import org.springframework.boot.test.context.SpringBootTest;",
    "",
    "@SpringBootTest",
    "class " .. class_name .. "Test {",
    "}",
  })

  local directory = vim.fs.dirname(destination)
  if vim.fn.mkdir(directory, "p") == 0 and not vim.uv.fs_stat(directory) then
    notify("Gagal membuat direktori: " .. directory, vim.log.levels.ERROR)
    return
  end

  local error_message = vim.fn.writefile(lines, destination)
  if error_message ~= 0 then
    notify("Gagal membuat file test: " .. destination, vim.log.levels.ERROR)
    return
  end

  vim.cmd.edit(vim.fn.fnameescape(destination))
  notify("Berhasil membuat " .. class_name .. "Test.java")
end

-- Keep the old entry point available for commands or mappings outside this config.
M.generate = M.open_or_generate

return M
