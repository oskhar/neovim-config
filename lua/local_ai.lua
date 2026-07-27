local M = {}

local model = "qwen2.5-coder:1.5b"
local max_context_bytes = 40 * 1024

local function show_result(output)
  vim.schedule(function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(output, "\n", { plain = true }))
    vim.cmd "botright 15split"
    vim.api.nvim_win_set_buf(0, buf)
  end)
end

local function run(instruction, source)
  if vim.fn.executable "ollama" ~= 1 then
    vim.notify("Ollama belum terpasang. Pasang secara lokal lalu jalankan: ollama pull " .. model, vim.log.levels.ERROR)
    return
  end

  local prompt = table.concat({
    "You are an offline coding assistant. No data may leave this machine.",
    "Infer naming, formatting, error handling, and architectural conventions from the supplied code.",
    "Follow those conventions consistently. Be concise and do not invent unavailable APIs.",
    "",
    "USER REQUEST:",
    instruction,
    "",
    "LOCAL CODE CONTEXT:",
    source:sub(1, max_context_bytes),
  }, "\n")

  vim.notify("Local AI sedang berjalan: " .. model, vim.log.levels.INFO)
  vim.system({ "ollama", "run", model, prompt }, {
    text = true,
    env = {
      OLLAMA_HOST = "127.0.0.1:11434",
      NO_PROXY = "127.0.0.1,localhost",
      no_proxy = "127.0.0.1,localhost",
    },
  }, function(result)
    if result.code == 0 then
      show_result(result.stdout)
    else
      vim.schedule(
        function() vim.notify("Local AI gagal: " .. (result.stderr or "unknown error"), vim.log.levels.ERROR) end
      )
    end
  end)
end

local function ask_with_source(source)
  vim.ui.input({ prompt = "Tanya AI lokal: " }, function(instruction)
    if instruction and instruction ~= "" then run(instruction, source) end
  end)
end

function M.ask() ask_with_source(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")) end

function M.ask_visual()
  local start_line = vim.fn.line "'<" - 1
  local end_line = vim.fn.line "'>"
  ask_with_source(table.concat(vim.api.nvim_buf_get_lines(0, start_line, end_line, false), "\n"))
end

return M
