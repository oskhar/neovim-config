local M = {}

local function current_jdtls(bufnr)
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr, name = "jdtls" }) do
    return client
  end
end

local function sha1(value)
  local result = vim.system({ "sha1sum" }, { stdin = value, text = true }):wait()
  if result.code ~= 0 then return nil, vim.trim(result.stderr or "sha1sum gagal") end
  local hash = (result.stdout or ""):match "^([%da-f]+)"
  if not hash or #hash ~= 40 then return nil, "Output sha1sum tidak valid" end
  return hash
end

function M.clear_project()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = current_jdtls(bufnr)
  if not client then
    vim.notify("JDTLS tidak aktif pada buffer ini", vim.log.levels.ERROR)
    return
  end

  local root = client.config.root_dir
  if type(root) ~= "string" or root == "" then
    vim.notify("Root project Java tidak ditemukan", vim.log.levels.ERROR)
    return
  end

  local hash, err = sha1(vim.fs.basename(root))
  if not hash then
    vim.notify("Tidak dapat menentukan cache project: " .. err, vim.log.levels.ERROR)
    return
  end

  local cache_root = vim.fs.normalize(vim.fn.stdpath "cache" .. "/jdtls")
  local cache_path = vim.fs.normalize(cache_root .. "/jdtls-" .. hash)
  local expected = "^" .. vim.pesc(cache_root) .. "/jdtls%-%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x$"
  if not cache_path:match(expected) then
    vim.notify("Menolak path cache yang tidak aman: " .. cache_path, vim.log.levels.ERROR)
    return
  end

  local config = vim.deepcopy(client.config)
  vim.notify("Membersihkan cache JDTLS untuk " .. vim.fs.basename(root) .. "…", vim.log.levels.INFO)
  client:stop(true)

  vim.defer_fn(function()
    local deleted = vim.fn.delete(cache_path, "rf")
    if deleted ~= 0 and (vim.uv or vim.loop).fs_stat(cache_path) then
      vim.notify("Gagal menghapus cache: " .. cache_path, vim.log.levels.ERROR)
      return
    end

    local id = vim.lsp.start(config, {
      bufnr = bufnr,
      reuse_client = function() return false end,
    })
    if id then
      vim.notify("Cache project dibersihkan; JDTLS sedang membangun ulang classpath", vim.log.levels.INFO)
    else
      vim.notify("Cache terhapus, tetapi JDTLS gagal dimulai kembali", vim.log.levels.ERROR)
    end
  end, 500)
end

return M
