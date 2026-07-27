local M = {}

local function position_before(row, col, other_row, other_col)
  return row < other_row or (row == other_row and col < other_col)
end

local function captures(capture)
  local parser = vim.treesitter.get_parser(0)
  local results = {}

  parser:for_each_tree(function(tree, language_tree)
    local query = vim.treesitter.query.get(language_tree:lang(), "textobjects")
    if not query then return end
    for id, node in query:iter_captures(tree:root(), 0, 0, -1) do
      if query.captures[id] == capture then
        local start_row, start_col, end_row, end_col = node:range()
        results[#results + 1] = {
          start_row = start_row,
          start_col = start_col,
          end_row = end_row,
          end_col = end_col,
        }
      end
    end
  end)

  table.sort(
    results,
    function(left, right) return position_before(left.start_row, left.start_col, right.start_row, right.start_col) end
  )
  return results
end

local function contains(item, row, col)
  local after_start = not position_before(row, col, item.start_row, item.start_col)
  local before_end = position_before(row, col, item.end_row, item.end_col)
  return after_start and before_end
end

local function size(item) return (item.end_row - item.start_row) * 1000000 + item.end_col - item.start_col end

function M.select(capture)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  local selected

  for _, item in ipairs(captures(capture)) do
    if contains(item, row, col) and (not selected or size(item) < size(selected)) then selected = item end
  end
  if not selected then
    for _, item in ipairs(captures(capture)) do
      if position_before(row, col, item.start_row, item.start_col) then
        selected = item
        break
      end
    end
  end
  if not selected then
    vim.notify("Semantic object tidak ditemukan: @" .. capture, vim.log.levels.WARN)
    return
  end

  local end_row, end_col = selected.end_row, selected.end_col
  if end_col == 0 and end_row > selected.start_row then
    end_row = end_row - 1
    end_col = #vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1]
  end
  end_col = math.max(0, end_col - 1)

  vim.api.nvim_win_set_cursor(0, { selected.start_row + 1, selected.start_col })
  vim.cmd "normal! v"
  vim.api.nvim_win_set_cursor(0, { end_row + 1, end_col })
end

function M.move(capture, forward)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  local items = captures(capture)
  local target

  if forward then
    for _, item in ipairs(items) do
      if position_before(row, col, item.start_row, item.start_col) then
        target = item
        break
      end
    end
  else
    for index = #items, 1, -1 do
      local item = items[index]
      if position_before(item.start_row, item.start_col, row, col) then
        target = item
        break
      end
    end
  end

  if target then
    vim.cmd "normal! m'"
    vim.api.nvim_win_set_cursor(0, { target.start_row + 1, target.start_col })
  end
end

return M
