local M = {}

local sql_filetypes = { sql = true, mysql = true, plsql = true }
local engines = {
  { name = "MySQL / MariaDB", scheme = "mariadb", port = 3306 },
  { name = "PostgreSQL", scheme = "postgresql", port = 5432 },
}

local function encode(value)
  return (value:gsub("([^%w%-._~])", function(character)
    return string.format("%%%02X", string.byte(character))
  end))
end

local function connection_file()
  local directory = vim.g.db_ui_save_location or (vim.fn.stdpath "data" .. "/db_ui")
  return directory .. "/connections.json"
end

local function active_connection_file()
  local directory = vim.g.db_ui_save_location or (vim.fn.stdpath "data" .. "/db_ui")
  return directory .. "/active_connection"
end

local function save_active_connection(name)
  local path = active_connection_file()
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p", 448)
  local ok, result = pcall(vim.fn.writefile, { name }, path)
  if ok and result == 0 then vim.uv.fs_chmod(path, 384) end
end

local function read_saved_connections(path)
  if vim.fn.filereadable(path) == 0 then return {} end
  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
  if ok and type(decoded) == "table" then return decoded end
  error("File koneksi tidak valid: " .. path)
end

local function unique_name(saved, base)
  local used = {}
  for _, item in ipairs(saved) do
    used[item.name] = true
  end
  if not used[base] then return base end
  local suffix = 2
  while used[string.format("%s (%d)", base, suffix)] do
    suffix = suffix + 1
  end
  return string.format("%s (%d)", base, suffix)
end

local function save_connection(name, url)
  local path = connection_file()
  local ok, saved = pcall(read_saved_connections, path)
  if not ok then
    vim.notify(saved, vim.log.levels.ERROR)
    return false
  end

  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p", 448)
  table.insert(saved, { name = unique_name(saved, name), url = url })
  local write_ok, result = pcall(vim.fn.writefile, { vim.json.encode(saved) }, path)
  if not write_ok or result ~= 0 then
    vim.notify("Gagal menyimpan koneksi ke " .. path, vim.log.levels.ERROR)
    return false
  end
  vim.uv.fs_chmod(path, 384)
  return true
end

function M.migrate_mariadb_client()
  if vim.fn.executable "mariadb" ~= 1 then return 0 end
  local path = connection_file()
  if vim.fn.filereadable(path) == 0 then return 0 end

  local ok, saved = pcall(read_saved_connections, path)
  if not ok then return 0 end
  local changed = 0
  for _, item in ipairs(saved) do
    if type(item.url) == "string" and item.url:match "^mysql://" then
      item.url = item.url:gsub("^mysql://", "mariadb://", 1)
      changed = changed + 1
    end
  end
  if changed == 0 then return 0 end

  local write_ok, result = pcall(vim.fn.writefile, { vim.json.encode(saved) }, path)
  if write_ok and result == 0 then
    vim.uv.fs_chmod(path, 384)
    return changed
  end
  return 0
end

local function is_sql_buffer()
  if sql_filetypes[vim.bo.filetype] then return true end
  vim.notify("Perintah database hanya tersedia pada buffer SQL", vim.log.levels.WARN)
  return false
end

local function ensure_dadbod()
  if vim.fn.exists(":DB") == 2 then return true end

  local ok, lazy = pcall(require, "lazy")
  if ok then lazy.load { plugins = { "vim-dadbod" } } end
  if vim.fn.exists(":DB") == 2 then return true end

  vim.notify("Dadbod belum berhasil dimuat; restart Neovim lalu coba lagi.", vim.log.levels.ERROR)
  return false
end

local function connections()
  local ok, result = pcall(vim.fn["db_ui#connections_list"])
  if not ok then
    vim.notify("DB UI belum siap: " .. tostring(result), vim.log.levels.ERROR)
    return {}
  end
  return result
end

local function select_connection(callback)
  local available = connections()
  if vim.tbl_isempty(available) then
    vim.notify("Belum ada koneksi. Gunakan <Leader>Da untuk menambah koneksi.", vim.log.levels.WARN)
    return
  end

  vim.ui.select(available, {
    prompt = "Pilih koneksi database",
    format_item = function(item)
      local status = item.is_connected == 1 and "connected" or item.source
      return string.format("%s  [%s]", item.name, status)
    end,
  }, function(item)
    if not item then return end
    vim.b.db = item.url
    vim.b.database_connection_name = item.name
    save_active_connection(item.name)
    M.test_connection(function(connected)
      if connected and callback then callback() end
    end)
  end)
end

local function safe_error(message)
  return tostring(message):gsub("://([^:/@]+):[^@]*@", "://%1:***@"):match "^[^\n]*"
end

function M.test_connection(callback)
  local url = vim.b.db
  if type(url) ~= "string" or url == "" then
    vim.b.database_connection_status = "disconnected"
    vim.notify("Belum ada koneksi untuk buffer ini. Gunakan <Leader>Ds.", vim.log.levels.WARN)
    if callback then callback(false) end
    return
  end

  vim.notify("Menguji koneksi database...", vim.log.levels.INFO)
  local ok, result = pcall(vim.fn["db#connect"], url)
  if ok and type(result) == "string" and result ~= "" then
    vim.b.database_connection_status = "connected"
    vim.b.database_connection_checked_at = os.date "%H:%M:%S"
    local name = vim.b.database_connection_name or "database"
    vim.notify("✓ Koneksi berhasil: " .. name, vim.log.levels.INFO)
    if callback then callback(true) end
    return
  end

  vim.b.database_connection_status = "failed"
  vim.b.database_connection_checked_at = os.date "%H:%M:%S"
  vim.notify("✗ Koneksi gagal: " .. safe_error(result), vim.log.levels.ERROR)
  if callback then callback(false) end
end

local function with_connection(callback)
  if type(vim.b.db) == "string" and vim.b.db ~= "" then
    callback()
  else
    select_connection(callback)
  end
end

local function execute_range(first, last)
  if not is_sql_buffer() then return end
  if not ensure_dadbod() then return end
  with_connection(function()
    vim.cmd({ cmd = "DB", range = { first, last } })
  end)
end

function M.setup_connection()
  vim.ui.select(engines, {
    prompt = "Pilih jenis database",
    format_item = function(item) return item.name end,
  }, function(engine)
    if not engine then return end

    local username = vim.trim(vim.fn.input "Username: ")
    if username == "" then
      vim.notify("Username wajib diisi", vim.log.levels.WARN)
      return
    end

    local password = vim.fn.inputsecret "Password: "
    local database = vim.trim(vim.fn.input "Database (opsional): ")
    local auth = encode(username)
    if password ~= "" then auth = auth .. ":" .. encode(password) end

    local url = string.format("%s://%s@localhost:%d", engine.scheme, auth, engine.port)
    if database ~= "" then url = url .. "/" .. encode(database) end

    local name = string.format("%s:%s", engine.scheme, username)
    if database ~= "" then name = name .. "/" .. database end
    if not save_connection(name, url) then return end

    vim.b.db = url
    vim.b.database_connection_name = name
    save_active_connection(name)
    M.test_connection()
  end)
end

function M.select_connection() select_connection() end

function M.execute_line()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  execute_range(line, line)
end

function M.execute_buffer()
  execute_range(1, vim.api.nvim_buf_line_count(0))
end

function M.execute_selection()
  if not is_sql_buffer() then return end
  if not ensure_dadbod() then return end

  -- Capture the selection type before a connection picker can change modes.
  local selection_mode = vim.fn.visualmode()
  local first = vim.fn.getpos("'<")[2]
  local last = vim.fn.getpos("'>")[2]
  if first > last then first, last = last, first end

  with_connection(function()
    -- Avoid '<,'>DB here: executing mark-based Ex ranges from a Lua callback
    -- can be parsed as a range on the callback command and raise E481. A
    -- numeric range is unambiguous for linewise selections.
    if selection_mode == "V" then
      vim.cmd({ cmd = "DB", range = { first, last } })
      return
    end

    -- Dadbod's zero range preserves exact character and block boundaries.
    local command = vim.fn["db#range"](selection_mode)
    vim.cmd(command)
  end)
end

function M.restore_active_connection()
  if not sql_filetypes[vim.bo.filetype] then return end
  if type(vim.b.db) == "string" and vim.b.db ~= "" then return end

  local path = active_connection_file()
  if vim.fn.filereadable(path) == 0 then return end
  local active_name = vim.trim((vim.fn.readfile(path)[1] or ""))
  if active_name == "" then return end

  local ok, saved = pcall(read_saved_connections, connection_file())
  if not ok then return end
  for _, item in ipairs(saved) do
    if item.name == active_name and type(item.url) == "string" and item.url ~= "" then
      vim.b.db = item.url
      vim.b.database_connection_name = item.name
      vim.b.database_connection_status = "saved"
      return
    end
  end
end

function M.setup_auto_restore()
  local group = vim.api.nvim_create_augroup("database_auto_restore", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "sql", "mysql", "plsql" },
    callback = M.restore_active_connection,
    desc = "Restore the last active database connection",
  })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "*",
    callback = M.restore_active_connection,
    desc = "Keep the saved database connection active",
  })
end

return M
