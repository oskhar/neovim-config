local M = {}

local last_task

local markers = {
  "go.mod",
  "pom.xml",
  "mvnw",
  "gradlew",
  "build.gradle",
  "build.gradle.kts",
  ".git",
}

local function exists(path) return path and (vim.uv or vim.loop).fs_stat(path) ~= nil end

local function join(...) return vim.fs.joinpath(...) end

local function executable(root, local_name, fallback)
  local local_path = join(root, local_name)
  if exists(local_path) then return local_path end
  return fallback
end

local function context()
  local file = vim.api.nvim_buf_get_name(0)
  local root = vim.fs.root(0, markers)
  if not root then return nil, "Project root tidak ditemukan" end

  if exists(join(root, "go.mod")) then
    return { kind = "go", root = root, file = file }
  elseif exists(join(root, "pom.xml")) or exists(join(root, "mvnw")) then
    return {
      kind = "maven",
      root = root,
      file = file,
      tool = executable(root, "mvnw", "mvn"),
    }
  elseif
    exists(join(root, "gradlew"))
    or exists(join(root, "build.gradle"))
    or exists(join(root, "build.gradle.kts"))
  then
    return {
      kind = "gradle",
      root = root,
      file = file,
      tool = executable(root, "gradlew", "gradle"),
    }
  end

  return nil, "Hanya proyek Go, Maven, dan Gradle yang didukung"
end

local function relative_package(ctx)
  local directory = vim.fs.dirname(ctx.file)
  local relative = vim.fs.relpath(ctx.root, directory)
  if not relative or relative == "." then return "." end
  return "./" .. relative
end

local function java_class(ctx)
  local class = vim.fn.fnamemodify(ctx.file, ":t:r")
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, math.min(100, vim.api.nvim_buf_line_count(0)), false)) do
    local package = line:match "^%s*package%s+([%w_.]+)%s*;"
    if package then return package .. "." .. class end
  end
  return class
end

local function nearest_go_test()
  local lines = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_win_get_cursor(0)[1], false)
  for index = #lines, 1, -1 do
    local name = lines[index]:match "^%s*func%s+(Test[%w_]+)%s*%("
    if name then return name end
  end
end

local function nearest_java_test()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, cursor_line, false)
  for index = #lines, 1, -1 do
    local name = lines[index]:match "^%s*.-([%a_][%w_]*)%s*%([^;]*%)%s*{"
    if name then
      if name:match "^test" then return name end
      for annotation_line = index - 1, math.max(1, index - 5), -1 do
        local annotation = lines[annotation_line]
        if
          annotation:match "@Test%f[%W]"
          or annotation:match "@ParameterizedTest%f[%W]"
          or annotation:match "@RepeatedTest%f[%W]"
        then
          return name
        end
      end
    end
  end
end

local function go_run(ctx)
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, math.min(30, vim.api.nvim_buf_line_count(0)), false)) do
    if line:match "^%s*package%s+main%s*$" then
      return { title = "Go run", cmd = { "go", "run", "." }, cwd = vim.fs.dirname(ctx.file) }
    end
  end

  local main_files = vim.fs.find("main.go", { path = ctx.root, type = "file", limit = 20 })
  local commands = {}
  for _, file in ipairs(main_files) do
    local command_dir = file:match "(/cmd/[^/]+)/main%.go$"
    if command_dir then commands[#commands + 1] = "." .. command_dir:sub(#ctx.root + 1) end
  end
  if #commands == 1 then return { title = "Go run", cmd = { "go", "run", commands[1] }, cwd = ctx.root } end

  return { title = "Go run", cmd = { "go", "run", "." }, cwd = ctx.root }
end

local function quickfix_path(cwd, filename, cache)
  if cache[filename] ~= nil then return cache[filename] or nil end
  if filename:sub(1, 1) == "/" and exists(filename) then
    cache[filename] = filename
    return filename
  end

  local direct = join(cwd, filename)
  if exists(direct) then
    cache[filename] = direct
    return direct
  end

  local matches = vim.fs.find(vim.fs.basename(filename), { path = cwd, type = "file", limit = 2 })
  cache[filename] = #matches == 1 and matches[1] or false
  return cache[filename] or nil
end

local function diagnostic_items(output, cwd)
  local items, seen, path_cache = {}, {}, {}
  local function add(filename, line, column, message)
    local path = quickfix_path(cwd, filename, path_cache)
    if not path then return end
    local key = table.concat({ path, line, column or 1, message }, ":")
    if seen[key] then return end
    seen[key] = true
    items[#items + 1] = {
      filename = path,
      lnum = tonumber(line),
      col = tonumber(column) or 1,
      text = vim.trim(message ~= "" and message or "Test failure"),
      type = "E",
    }
  end

  for _, line in ipairs(vim.split(output, "\n", { plain = true })) do
    local file, lnum, col, message = line:match "^%s*%[ERROR%]%s+(.+%.java):%[(%d+),(%d+)%]%s*(.*)"
    if file then
      add(file, lnum, col, message)
    else
      file, lnum, col, message = line:match "^%s*([^:%s]+%.go):(%d+):(%d+):%s*(.*)"
      if file then
        add(file, lnum, col, message)
      else
        file, lnum, message = line:match "^%s*([^:%s]+%.go):(%d+):%s*(.*)"
        if file then
          add(file, lnum, 1, message)
        else
          file, lnum, message = line:match "^%s*(.-%.java):(%d+):%s*(.*)"
          if file then
            add(file, lnum, 1, message)
          else
            file, lnum = line:match "^%s*at%s+[%w_.$<>]+%(([%w_$%-]+%.java):(%d+)%)%s*$"
            if file then add(file, lnum, 1, vim.trim(line)) end
          end
        end
      end
    end
  end
  return items
end

local function quickfix(title, output, cwd)
  local items = diagnostic_items(output, cwd)
  if #items > 0 then
    vim.fn.setqflist({}, " ", { title = title, items = items })
    return
  end

  -- Never put unverified paths in quickfix: :cnext would create bogus files.
  vim.fn.setqflist({}, " ", { title = title, items = {} })
end

local function failure_output(task, result)
  local stdout = result.stdout or ""
  local stderr = result.stderr or ""
  local lines = {
    "TASK FAILED",
    "",
    "Command : " .. table.concat(task.cmd, " "),
    "CWD     : " .. task.cwd,
    "Exit    : " .. tostring(result.code),
    "Signal  : " .. tostring(result.signal),
    "",
    "========== STDOUT ==========",
  }
  vim.list_extend(lines, vim.split(stdout, "\n", { plain = true }))
  vim.list_extend(lines, { "", "========== STDERR ==========" })
  vim.list_extend(lines, vim.split(stderr, "\n", { plain = true }))
  vim.list_extend(lines, {
    "",
    "========== NAVIGATION ==========",
    "Lokasi error yang berhasil dikenali tersedia di quickfix (:copen).",
    "Gunakan :cnext dan :cprev untuk berpindah antar-error.",
  })

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "project-task://failure-" .. tostring(vim.uv.hrtime()))
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = "log"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  vim.cmd "botright 20split"
  vim.api.nvim_win_set_buf(0, buf)
  vim.wo.wrap = false
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = buf, silent = true, desc = "Close task output" })
  vim.keymap.set("n", "<Leader>qo", "<Cmd>copen<CR>", {
    buffer = buf,
    silent = true,
    desc = "Open parsed errors in quickfix",
  })
end

local function save_current_buffer()
  if vim.bo.modified and vim.bo.buftype == "" then vim.cmd "silent update" end
end

local function execute(task)
  last_task = vim.deepcopy(task)
  save_current_buffer()
  vim.notify("Menjalankan: " .. table.concat(task.cmd, " "), vim.log.levels.INFO)

  vim.system(task.cmd, { cwd = task.cwd, text = true }, function(result)
    vim.schedule(function()
      local output = (result.stdout or "") .. (result.stderr or "")
      quickfix(task.title, output, task.cwd)
      if result.code == 0 then
        vim.notify(task.title .. " berhasil", vim.log.levels.INFO)
      else
        vim.notify(task.title .. " gagal (exit " .. result.code .. ")", vim.log.levels.ERROR)
        failure_output(task, result)
      end
    end)
  end)
end

local function terminal(task)
  last_task = vim.deepcopy(task)
  save_current_buffer()
  vim.cmd "botright 15split"
  vim.cmd "enew"
  vim.bo.bufhidden = "wipe"
  vim.fn.jobstart(task.cmd, { cwd = task.cwd, term = true })
  vim.cmd "startinsert"
end

local function resolve(action)
  local ctx, err = context()
  if not ctx then return nil, err end

  if action == "test_file" then
    if ctx.kind == "go" then
      return { title = "Go test package", cmd = { "go", "test", relative_package(ctx) }, cwd = ctx.root }
    elseif ctx.kind == "maven" then
      return {
        title = "Maven test class",
        cmd = { ctx.tool, "-Dtest=" .. java_class(ctx), "test" },
        cwd = ctx.root,
      }
    else
      return {
        title = "Gradle test class",
        cmd = { ctx.tool, "test", "--tests", java_class(ctx) },
        cwd = ctx.root,
      }
    end
  elseif action == "test_all" then
    if ctx.kind == "go" then return { title = "Go test project", cmd = { "go", "test", "./..." }, cwd = ctx.root } end
    return {
      title = ctx.kind == "maven" and "Maven test project" or "Gradle test project",
      cmd = ctx.kind == "maven" and { ctx.tool, "test" } or { ctx.tool, "test" },
      cwd = ctx.root,
    }
  elseif action == "test_nearest" then
    if ctx.kind == "go" then
      local test = nearest_go_test()
      if not test then return nil, "Tidak menemukan fungsi Test... di atas cursor" end
      return {
        title = "Go nearest test: " .. test,
        cmd = { "go", "test", relative_package(ctx), "-run", "^" .. test .. "$", "-count=1" },
        cwd = ctx.root,
      }
    end

    local method = nearest_java_test()
    if not method then return nil, "Tidak menemukan method Java di atas cursor" end
    local class = java_class(ctx)
    return ctx.kind == "maven"
        and {
          title = "Maven nearest test: " .. method,
          cmd = { ctx.tool, "-Dtest=" .. class .. "#" .. method, "test" },
          cwd = ctx.root,
        }
      or {
        title = "Gradle nearest test: " .. method,
        cmd = { ctx.tool, "test", "--tests", class .. "." .. method },
        cwd = ctx.root,
      }
  elseif action == "run" then
    if ctx.kind == "go" then
      return go_run(ctx)
    elseif ctx.kind == "maven" then
      return { title = "Maven run", cmd = { ctx.tool, "spring-boot:run" }, cwd = ctx.root }
    else
      return { title = "Gradle run", cmd = { ctx.tool, "bootRun" }, cwd = ctx.root }
    end
  elseif action == "build" then
    if ctx.kind == "go" then
      return { title = "Go build", cmd = { "go", "build", "./..." }, cwd = ctx.root }
    elseif ctx.kind == "maven" then
      return { title = "Maven build", cmd = { ctx.tool, "package", "-DskipTests" }, cwd = ctx.root }
    else
      return { title = "Gradle build", cmd = { ctx.tool, "build", "-x", "test" }, cwd = ctx.root }
    end
  end
end

local function dispatch(action, use_terminal)
  local task, err = resolve(action)
  if not task then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  if use_terminal then
    terminal(task)
  else
    execute(task)
  end
end

function M.test_file() dispatch "test_file" end
function M.test_all() dispatch "test_all" end
function M.test_nearest() dispatch "test_nearest" end
function M.run() dispatch("run", true) end
function M.build() dispatch "build" end

function M.run_last()
  if not last_task then
    vim.notify("Belum ada project task yang dijalankan", vim.log.levels.WARN)
    return
  end
  if last_task.title:match " run$" then
    terminal(last_task)
  else
    execute(last_task)
  end
end

M._resolve = resolve

return M
