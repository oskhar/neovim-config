local M = {}

local last_task
local running_task
local last_application_buffer
local application_status = { state = "stopped", label = "App: stopped" }
local test_notification_timeout = 30000
local run_config_file = vim.fn.stdpath "data" .. "/project_tasks_run_config.json"

local function set_application_status(state, label)
  application_status = { state = state, label = label }
  vim.api.nvim_exec_autocmds("User", { pattern = "ProjectTaskStatus", modeline = false })
  vim.cmd "redrawstatus"
end

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

local function canonical(path)
  return (vim.uv or vim.loop).fs_realpath(path) or vim.fs.normalize(path)
end

local function find_upward(start, name)
  local found = vim.fs.find(name, { path = start, upward = true, type = "file", limit = 1 })
  return found[1]
end

local function maven_context(file)
  local start = file ~= "" and vim.fs.dirname(file) or (vim.uv or vim.loop).cwd()
  local pom = find_upward(start, "pom.xml")
  if not pom then return nil end

  -- The closest pom.xml owns the opened file. A wrapper may live in that module
  -- or in any parent (common in multi-module/microservice repositories).
  local module_root = vim.fs.dirname(pom)
  local wrapper = find_upward(module_root, "mvnw")
  return {
    kind = "maven",
    root = module_root,
    file = file,
    tool = wrapper or "mvn",
  }
end

local function context()
  local file = vim.api.nvim_buf_get_name(0)
  local root = vim.fs.root(0, markers)
  if not root then return nil, "Project root tidak ditemukan" end

  if exists(join(root, "go.mod")) then
    return { kind = "go", root = root, file = file }
  elseif find_upward(file ~= "" and vim.fs.dirname(file) or root, "pom.xml") then
    return maven_context(file)
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

local function read_run_configs()
  local ok, lines = pcall(vim.fn.readfile, run_config_file)
  if not ok or #lines == 0 then return {} end
  local decoded_ok, configs = pcall(vim.json.decode, table.concat(lines, "\n"))
  return decoded_ok and type(configs) == "table" and configs or {}
end

local function write_run_configs(configs)
  vim.fn.mkdir(vim.fs.dirname(run_config_file), "p")
  local ok, err = pcall(vim.fn.writefile, { vim.json.encode(configs) }, run_config_file)
  if not ok then vim.notify("Gagal menyimpan Program arguments: " .. tostring(err), vim.log.levels.ERROR) end
  return ok
end

local function saved_program_arguments(ctx)
  local config = read_run_configs()[canonical(ctx.root)]
  return type(config) == "table" and config.program_arguments or ""
end

local function save_program_arguments(ctx, arguments)
  local configs = read_run_configs()
  configs[canonical(ctx.root)] = {
    program_arguments = arguments,
    pom = join(canonical(ctx.root), "pom.xml"),
  }
  return write_run_configs(configs)
end

local function maven_run_task(ctx, arguments)
  local cmd = { ctx.tool }
  if arguments ~= "" then cmd[#cmd + 1] = "-Dspring-boot.run.arguments=" .. arguments end
  cmd[#cmd + 1] = "spring-boot:run"
  return {
    title = "Maven run: " .. vim.fs.basename(ctx.root),
    cmd = cmd,
    cwd = ctx.root,
    context = ctx,
  }
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

local function report_files(task)
  if not task.report_kind or task.report_kind == "go" then return {} end
  local marker = task.report_kind == "maven" and "/target/surefire-reports/" or "/build/test-results/test/"
  return vim.fs.find(function(name, path)
    return name:match "%.xml$" ~= nil and (path .. "/"):find(marker, 1, true) ~= nil
  end, { path = task.cwd, type = "file", limit = math.huge })
end

local function file_signature(path)
  local stat = (vim.uv or vim.loop).fs_stat(path)
  if not stat then return nil end
  local mtime = stat.mtime or {}
  return table.concat({ stat.size or 0, mtime.sec or 0, mtime.nsec or 0 }, ":")
end

local function report_snapshot(task)
  local snapshot = {}
  for _, path in ipairs(report_files(task)) do
    snapshot[path] = file_signature(path)
  end
  return snapshot
end

local function xml_decode(value)
  local entities = { amp = "&", lt = "<", gt = ">", quot = '"', apos = "'" }
  return (value:gsub("&(#?x?[%w]+);", function(entity)
    if entities[entity] then return entities[entity] end
    local hex = entity:match "^#x([%da-fA-F]+)$"
    local decimal = entity:match "^#(%d+)$"
    local codepoint = tonumber(hex, 16) or tonumber(decimal)
    return codepoint and vim.fn.nr2char(codepoint) or "&" .. entity .. ";"
  end))
end

local function xml_attribute(attributes, name)
  local value = attributes:match(name .. '%s*=%s*"([^"]*)"')
    or attributes:match(name .. "%s*=%s*'([^']*)'")
  return value and xml_decode(value) or nil
end

local function java_passed_tests(task, before)
  local tests = {}
  for _, path in ipairs(report_files(task)) do
    if before[path] ~= file_signature(path) then
      local file = io.open(path, "r")
      local xml = file and file:read "*a" or ""
      if file then file:close() end

      local position = 1
      while true do
        local first, last, attributes, slash = xml:find("<testcase%s+([^>]-)(/?)>", position)
        if not first then break end
        local body = ""
        if slash ~= "/" then
          local close_first, close_last = xml:find("</testcase%s*>", last + 1)
          if not close_first then break end
          body = xml:sub(last + 1, close_first - 1)
          position = close_last + 1
        else
          position = last + 1
        end

        if not body:find("<skipped[%s/>]") and not body:find("<failure[%s/>]") and not body:find("<error[%s/>]") then
          local name = xml_attribute(attributes, "name")
          if name then tests[#tests + 1] = name end
        end
      end
    end
  end
  table.sort(tests)
  return tests
end

local function go_passed_tests(output)
  local tests = {}
  for line in output:gmatch "[^\r\n]+" do
    if line:find '"Action"%s*:%s*"pass"' then
      local name = line:match '"Test"%s*:%s*"([^"]+)"'
      if name then tests[#tests + 1] = name end
    end
  end
  return tests
end

local function success_message(task, output, before)
  if not task.test_task then return task.title .. " berhasil" end
  local tests = task.report_kind == "go" and go_passed_tests(output) or java_passed_tests(task, before)
  local lines = { string.format("%s berhasil — %d test berhasil", task.title, #tests) }
  if #tests == 0 then
    lines[#lines + 1] = "Tidak ada nama test yang terdeteksi dari hasil eksekusi."
  else
    for _, name in ipairs(tests) do
      lines[#lines + 1] = "• " .. name
    end
  end
  return table.concat(lines, "\n")
end

local function execute(task)
  last_task = vim.deepcopy(task)
  save_current_buffer()
  local before = report_snapshot(task)
  vim.notify("Menjalankan: " .. table.concat(task.cmd, " "), vim.log.levels.INFO)

  vim.system(task.cmd, { cwd = task.cwd, text = true }, function(result)
    vim.schedule(function()
      local output = (result.stdout or "") .. (result.stderr or "")
      quickfix(task.title, output, task.cwd)
      if result.code == 0 then
        vim.notify(success_message(task, output, before), vim.log.levels.INFO, {
          timeout = task.test_task and test_notification_timeout or nil,
        })
      else
        vim.notify(task.title .. " gagal (exit " .. result.code .. ")", vim.log.levels.ERROR)
        failure_output(task, result)
      end
    end)
  end)
end

local function terminal(task)
  if running_task then
    vim.notify("Application masih berjalan. Hentikan dulu dengan <Leader>rs", vim.log.levels.WARN)
    return
  end

  last_task = vim.deepcopy(task)
  save_current_buffer()
  if last_application_buffer and vim.api.nvim_buf_is_valid(last_application_buffer) then
    pcall(vim.api.nvim_buf_delete, last_application_buffer, { force = true })
  end
  -- Start in a hidden terminal buffer. <Leader>ro reveals it on demand.
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].bufhidden = "hide"
  last_application_buffer = buffer
  local job_id
  vim.api.nvim_buf_call(buffer, function()
    job_id = vim.fn.jobstart(task.cmd, {
      cwd = task.cwd,
      term = true,
      on_exit = function(id, exit_code)
        vim.schedule(function()
          if not running_task or running_task.job_id ~= id then return end
          local stopped_by_user = running_task.stopping
          running_task = nil
          if stopped_by_user then
            set_application_status("stopped", "App: stopped")
            vim.notify("Application dihentikan", vim.log.levels.INFO)
          elseif exit_code == 0 then
            set_application_status("stopped", "App: finished")
            vim.notify(task.title .. " selesai", vim.log.levels.INFO)
          else
            set_application_status("failed", "App: failed (exit " .. exit_code .. ")")
            vim.notify(
              task.title .. " gagal (exit " .. exit_code .. "). Buka log dengan <Leader>ro.",
              vim.log.levels.ERROR
            )
          end
        end)
      end,
    })
  end)
  if job_id <= 0 then
    set_application_status("failed", "App: failed to start")
    vim.notify("Gagal memulai application: jobstart mengembalikan " .. job_id, vim.log.levels.ERROR)
    return
  end
  running_task = { job_id = job_id, task = vim.deepcopy(task), buffer = buffer }
  set_application_status("running", "App: running (" .. task.title .. ")")
end

local function terminal_output(task)
  last_task = vim.deepcopy(task)
  save_current_buffer()
  vim.cmd "botright 15split"
  vim.cmd "enew"
  vim.bo.bufhidden = "wipe"
  local buffer = vim.api.nvim_get_current_buf()
  vim.bo[buffer].filetype = "log"
  vim.fn.jobstart(task.cmd, {
    cwd = task.cwd,
    term = true,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code == 0 then
          vim.notify(task.title .. " berhasil — full log tersedia di terminal", vim.log.levels.INFO)
        else
          vim.notify(task.title .. " gagal (exit " .. exit_code .. ") — lihat full log di terminal", vim.log.levels.ERROR)
          if vim.api.nvim_buf_is_valid(buffer) then
            local window = vim.fn.bufwinid(buffer)
            if window ~= -1 then vim.api.nvim_set_current_win(window) end
          end
        end
      end)
    end,
  })
  vim.cmd "startinsert"
end

local function resolve(action)
  local ctx, err = context()
  if not ctx then return nil, err end

  if action == "test_file" then
    if ctx.kind == "go" then
      return {
        title = "Go test package",
        cmd = { "go", "test", "-json", relative_package(ctx) },
        cwd = ctx.root,
        test_task = true,
        report_kind = "go",
      }
    elseif ctx.kind == "maven" then
      return {
        title = "Maven test class",
        cmd = { ctx.tool, "-Dtest=" .. java_class(ctx), "test" },
        cwd = ctx.root,
        test_task = true,
        report_kind = "maven",
      }
    else
      return {
        title = "Gradle test class",
        cmd = { ctx.tool, "test", "--tests", java_class(ctx) },
        cwd = ctx.root,
        test_task = true,
        report_kind = "gradle",
      }
    end
  elseif action == "test_all" then
    if ctx.kind == "go" then
      return {
        title = "Go test project",
        cmd = { "go", "test", "-json", "./..." },
        cwd = ctx.root,
        test_task = true,
        report_kind = "go",
      }
    end
    return {
      title = ctx.kind == "maven" and "Maven test project" or "Gradle test project",
      cmd = ctx.kind == "maven" and { ctx.tool, "test" } or { ctx.tool, "test" },
      cwd = ctx.root,
      test_task = true,
      report_kind = ctx.kind,
    }
  elseif action == "test_nearest" then
    if ctx.kind == "go" then
      local test = nearest_go_test()
      if not test then return nil, "Tidak menemukan fungsi Test... di atas cursor" end
      return {
        title = "Go nearest test: " .. test,
        cmd = { "go", "test", "-json", relative_package(ctx), "-run", "^" .. test .. "$", "-count=1" },
        cwd = ctx.root,
        test_task = true,
        report_kind = "go",
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
          test_task = true,
          report_kind = "maven",
        }
      or {
        title = "Gradle nearest test: " .. method,
        cmd = { ctx.tool, "test", "--tests", class .. "." .. method },
        cwd = ctx.root,
        test_task = true,
        report_kind = "gradle",
      }
  elseif action == "run" then
    if ctx.kind == "go" then
      return go_run(ctx)
    elseif ctx.kind == "maven" then
      return maven_run_task(ctx, saved_program_arguments(ctx))
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
function M.test_nearest_full()
  local task, err = resolve "test_nearest"
  if not task then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  terminal_output(task)
end
function M.run()
  local ctx, err = context()
  if not ctx then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  if ctx.kind ~= "maven" then
    dispatch("run", true)
    return
  end

  vim.ui.input({
    prompt = "Program arguments [" .. vim.fs.basename(ctx.root) .. "]: ",
    default = saved_program_arguments(ctx),
  }, function(arguments)
    if arguments == nil then return end
    arguments = vim.trim(arguments)
    if not save_program_arguments(ctx, arguments) then return end

    terminal(maven_run_task(ctx, arguments))
  end)
end
function M.build() dispatch "build" end

function M.stop()
  if not running_task then
    vim.notify("Tidak ada application yang sedang berjalan", vim.log.levels.WARN)
    return
  end
  running_task.stopping = true
  set_application_status("stopping", "App: stopping")
  if vim.fn.jobstop(running_task.job_id) == 0 then
    running_task.stopping = false
    set_application_status("failed", "App: failed to stop")
    vim.notify("Application gagal dihentikan", vim.log.levels.ERROR)
  end
end

function M.toggle_log()
  local buffer = running_task and running_task.buffer or last_application_buffer
  if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
    vim.notify("Belum ada log application", vim.log.levels.WARN)
    return
  end

  local window = vim.fn.bufwinid(buffer)
  if window ~= -1 then
    vim.api.nvim_win_close(window, false)
    return
  end

  vim.cmd "botright 15split"
  vim.api.nvim_win_set_buf(0, buffer)
  vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buffer), 0 })
  if running_task then vim.cmd "startinsert" end
end

function M.status() return vim.deepcopy(application_status) end

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
