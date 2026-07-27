local M = {}

local function git_root()
  local file = vim.api.nvim_buf_get_name(0)
  local directory = file == "" and vim.uv.cwd() or vim.fs.dirname(file)
  local result = vim.system({ "git", "-C", directory, "rev-parse", "--show-toplevel" }, { text = true }):wait()
  if result.code ~= 0 then return nil, "File ini tidak berada di dalam Git repository" end
  return vim.trim(result.stdout)
end

local function show_failure(title, command, cwd, result)
  local lines = {
    title,
    "",
    "Command : " .. table.concat(command, " "),
    "CWD     : " .. cwd,
    "Exit    : " .. tostring(result.code),
    "",
    "========== STDOUT ==========",
  }
  vim.list_extend(lines, vim.split(result.stdout or "", "\n", { plain = true }))
  vim.list_extend(lines, { "", "========== STDERR ==========" })
  vim.list_extend(lines, vim.split(result.stderr or "", "\n", { plain = true }))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "git-task://failure-" .. tostring(vim.uv.hrtime()))
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = "git"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.cmd "botright 15split"
  vim.api.nvim_win_set_buf(0, buf)
  vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = buf, silent = true })
end

local function execute(title, command, cwd, on_success)
  vim.notify(title .. ": " .. table.concat(command, " "), vim.log.levels.INFO)
  vim.system(command, { cwd = cwd, text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        vim.notify(title .. " berhasil", vim.log.levels.INFO)
        if on_success then on_success(result) end
      else
        vim.notify(title .. " gagal", vim.log.levels.ERROR)
        show_failure(title, command, cwd, result)
      end
    end)
  end)
end

local function terminal(command, cwd)
  vim.cmd "botright 15split"
  vim.cmd "enew"
  vim.bo.bufhidden = "wipe"
  vim.fn.jobstart(command, { cwd = cwd, term = true })
  vim.cmd "startinsert"
end

local function file_contains(path, pattern)
  if not (vim.uv or vim.loop).fs_stat(path) then return false end
  local ok, lines = pcall(vim.fn.readfile, path, "", 300)
  return ok and table.concat(lines, "\n"):match(pattern) ~= nil
end

local function commitizen_config(root)
  if (vim.uv or vim.loop).fs_stat(vim.fs.joinpath(root, ".czrc")) then return "js" end
  if file_contains(vim.fs.joinpath(root, "package.json"), '"commitizen"%s*:') then return "js" end
  for _, name in ipairs { ".cz.json", ".cz.toml", ".cz.yaml", ".cz.yml", "cz.toml" } do
    if (vim.uv or vim.loop).fs_stat(vim.fs.joinpath(root, name)) then return "python" end
  end
  if file_contains(vim.fs.joinpath(root, "pyproject.toml"), "%[tool%.commitizen%]") then return "python" end
end

local function commitizen_command(root, kind)
  local local_cz = vim.fs.joinpath(root, "node_modules", ".bin", "cz")
  if kind == "js" then
    if (vim.uv or vim.loop).fs_stat(local_cz) then return { local_cz } end
    if vim.fn.executable "cz" == 1 then return { "cz" } end
    if vim.fn.executable "npx" == 1 then return { "npx", "--no-install", "cz" } end
  elseif vim.fn.executable "cz" == 1 then
    return { "cz", "commit" }
  end
end

local function has_staged_changes(root)
  return vim.system({ "git", "diff", "--cached", "--quiet" }, { cwd = root }):wait().code == 1
end

function M.add_current()
  local root, err = git_root()
  if not root then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("Buffer aktif tidak memiliki file", vim.log.levels.ERROR)
    return
  end
  if vim.bo.modified then vim.cmd "silent update" end
  execute("Git add current file", { "git", "add", "--", file }, root)
end

function M.add_all()
  local root, err = git_root()
  if not root then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  execute("Git add all", { "git", "add", "-A" }, root)
end

function M.commit()
  local root, err = git_root()
  if not root then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  if not has_staged_changes(root) then
    vim.notify("Tidak ada staged changes. Gunakan <Leader>ga atau <Leader>gA terlebih dahulu.", vim.log.levels.WARN)
    return
  end

  local commitizen_kind = commitizen_config(root)
  if commitizen_kind then
    local command = commitizen_command(root, commitizen_kind)
    if not command then
      vim.notify("Konfigurasi Commitizen ditemukan, tetapi executable cz tidak tersedia.", vim.log.levels.ERROR)
      return
    end
    terminal(command, root)
    return
  end

  vim.ui.input({ prompt = "Commit message: " }, function(message)
    if message and vim.trim(message) ~= "" then
      execute("Git commit", { "git", "commit", "-m", vim.trim(message) }, root)
    end
  end)
end

function M.push()
  local root, err = git_root()
  if not root then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  terminal({ "git", "push" }, root)
end

return M
