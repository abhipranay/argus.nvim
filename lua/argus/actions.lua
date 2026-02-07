-- argus.nvim actions module
local M = {}

local window = require("argus.window")
local render = require("argus.render")
local parser = require("argus.parser")
local symbols_mod = require("argus.symbols")

---Get current cursor line in outline
---@return number
local function get_outline_cursor_line()
  local win = window.get_outline_win()
  if not win then
    return 0
  end
  return vim.api.nvim_win_get_cursor(win)[1]
end

---Set cursor line in outline
---@param line number
local function set_outline_cursor_line(line)
  local win = window.get_outline_win()
  if not win then
    return
  end
  local buf = window.get_outline_bufnr()
  if not buf then
    return
  end
  local line_count = vim.api.nvim_buf_line_count(buf)
  line = math.max(1, math.min(line, line_count))
  vim.api.nvim_win_set_cursor(win, { line, 0 })
end

---Jump to symbol in source buffer
function M.jump_to_symbol()
  local line = get_outline_cursor_line()
  local symbol = render.get_symbol_at_line(line)
  if not symbol then
    return
  end

  local source_win = window.get_source_win()
  if not source_win then
    return
  end

  -- Jump to source
  vim.api.nvim_set_current_win(source_win)
  vim.api.nvim_win_set_cursor(source_win, { symbol.code_start_line, 0 })
  vim.cmd("normal! zz")
end

---Toggle fold for symbol at cursor
function M.toggle_fold()
  local line = get_outline_cursor_line()
  local symbol = render.get_symbol_at_line(line)
  if not symbol or #symbol.children == 0 then
    return
  end

  symbol.collapsed = not symbol.collapsed

  -- Re-render
  local buf = window.get_outline_bufnr()
  if buf then
    render.render(buf, render.get_symbols())
  end

  -- Keep cursor on same symbol
  local new_line = render.get_line_for_symbol(symbol)
  if new_line then
    set_outline_cursor_line(new_line)
  end
end

---Expand all folds
function M.expand_all()
  local symbols_list = render.get_symbols()
  local flat = symbols_mod.flatten(symbols_list, true)

  for _, symbol in ipairs(flat) do
    symbol.collapsed = false
  end

  local buf = window.get_outline_bufnr()
  if buf then
    render.render(buf, symbols_list)
  end
end

---Collapse all folds
function M.collapse_all()
  local symbols_list = render.get_symbols()
  local flat = symbols_mod.flatten(symbols_list, true)

  for _, symbol in ipairs(flat) do
    if #symbol.children > 0 then
      symbol.collapsed = true
    end
  end

  local buf = window.get_outline_bufnr()
  if buf then
    render.render(buf, symbols_list)
  end
end

---Move symbol up in source code
function M.move_up()
  local outline_line = get_outline_cursor_line()
  local symbol = render.get_symbol_at_line(outline_line)
  if not symbol then
    return
  end

  local source_buf = window.get_source_bufnr()
  if not source_buf then
    return
  end

  -- Get siblings
  local siblings, index = symbols_mod.get_siblings(symbol, render.get_symbols())
  if index <= 1 then
    vim.notify("argus: Already at top", vim.log.levels.INFO)
    return
  end

  local prev_sibling = siblings[index - 1]
  M._swap_symbols(source_buf, symbol, prev_sibling, "up")
end

---Move symbol down in source code
function M.move_down()
  local outline_line = get_outline_cursor_line()
  local symbol = render.get_symbol_at_line(outline_line)
  if not symbol then
    return
  end

  local source_buf = window.get_source_bufnr()
  if not source_buf then
    return
  end

  -- Get siblings
  local siblings, index = symbols_mod.get_siblings(symbol, render.get_symbols())
  if index >= #siblings then
    vim.notify("argus: Already at bottom", vim.log.levels.INFO)
    return
  end

  local next_sibling = siblings[index + 1]
  M._swap_symbols(source_buf, symbol, next_sibling, "down")
end

---Swap two symbols in the source buffer
---@param source_buf number
---@param symbol Symbol The symbol being moved
---@param target Symbol The symbol to swap with
---@param direction string "up" or "down"
function M._swap_symbols(source_buf, symbol, target, direction)
  -- Determine which is first in file
  local first, second
  if symbol.start_line < target.start_line then
    first = symbol
    second = target
  else
    first = target
    second = symbol
  end

  -- Get lines for both symbols (0-indexed for API)
  local first_start = first.start_line - 1
  local first_end = first.end_line
  local second_start = second.start_line - 1
  local second_end = second.end_line

  -- Get the source lines
  local first_lines = vim.api.nvim_buf_get_lines(source_buf, first_start, first_end, false)
  local second_lines = vim.api.nvim_buf_get_lines(source_buf, second_start, second_end, false)

  -- Also get the blank lines between them (to preserve spacing)
  local between_start = first_end
  local between_end = second_start
  local between_lines = {}
  if between_end > between_start then
    between_lines = vim.api.nvim_buf_get_lines(source_buf, between_start, between_end, false)
  end

  -- Build new content: second, between, first
  local new_lines = {}
  for _, line in ipairs(second_lines) do
    table.insert(new_lines, line)
  end
  for _, line in ipairs(between_lines) do
    table.insert(new_lines, line)
  end
  for _, line in ipairs(first_lines) do
    table.insert(new_lines, line)
  end

  -- Replace entire range
  vim.api.nvim_buf_set_lines(source_buf, first_start, second_end, false, new_lines)

  -- Re-parse and re-render
  local new_symbols = parser.parse_buffer(source_buf)
  local outline_buf = window.get_outline_bufnr()
  if outline_buf then
    render.render(outline_buf, new_symbols)
  end

  -- Find the moved symbol and position cursor on it
  local moved_name = symbol.name
  local moved_kind = symbol.kind
  for new_line, sym in pairs(render.get_symbols()) do
    local flat = symbols_mod.flatten({ sym }, true)
    for _, s in ipairs(flat) do
      if s.name == moved_name and s.kind == moved_kind then
        local line = render.get_line_for_symbol(s)
        if line then
          set_outline_cursor_line(line)
          return
        end
      end
    end
  end

  -- Fallback: try to find by iterating all displayed symbols
  local displayed = symbols_mod.flatten(render.get_symbols(), false)
  for i, s in ipairs(displayed) do
    if s.name == moved_name and s.kind == moved_kind then
      set_outline_cursor_line(i)
      return
    end
  end
end

---Sync outline cursor to match source cursor position
function M.sync_cursor_from_source()
  local source_win = window.get_source_win()
  if not source_win or not vim.api.nvim_win_is_valid(source_win) then
    return
  end

  local source_line = vim.api.nvim_win_get_cursor(source_win)[1]
  local outline_line = render.find_outline_line_for_source(source_line)

  if outline_line then
    set_outline_cursor_line(outline_line)
  end
end

---Preview symbol without jumping (auto_preview feature)
function M.preview_symbol()
  local line = get_outline_cursor_line()
  local symbol = render.get_symbol_at_line(line)
  if not symbol then
    return
  end

  local source_win = window.get_source_win()
  if not source_win then
    return
  end

  -- Set cursor in source but don't switch windows
  vim.api.nvim_win_set_cursor(source_win, { symbol.code_start_line, 0 })
  -- Center the view in source window
  vim.api.nvim_win_call(source_win, function()
    vim.cmd("normal! zz")
  end)
end

---Refresh the outline
function M.refresh()
  local source_buf = window.get_source_bufnr()
  local outline_buf = window.get_outline_bufnr()

  if not source_buf or not outline_buf then
    return
  end

  local symbols_list = parser.parse_buffer(source_buf)
  render.render(outline_buf, symbols_list)
end

---Toggle between flat and hierarchy view modes
function M.toggle_view()
  local config = require("argus.config")
  local cfg = config.get()

  -- Toggle the view mode
  if cfg.view_mode == "flat" then
    cfg.view_mode = "hierarchy"
    vim.notify("argus: Hierarchy view", vim.log.levels.INFO)
  else
    cfg.view_mode = "flat"
    vim.notify("argus: Flat view (file order)", vim.log.levels.INFO)
  end

  -- Refresh to apply new view mode
  M.refresh()
end

---Get current view mode
---@return string
function M.get_view_mode()
  local config = require("argus.config")
  return config.get().view_mode or "flat"
end

---Show help popup with keybindings
function M.show_help()
  local config = require("argus.config")
  local km = config.get().keymaps

  local lines = {
    " Argus Outline - Keybindings ",
    "─────────────────────────────",
    "",
    string.format("  %-6s Close outline", km.close),
    string.format("  %-6s Jump to symbol", km.jump),
    string.format("  %-6s Move symbol up", km.move_up),
    string.format("  %-6s Move symbol down", km.move_down),
    string.format("  %-6s Toggle fold", km.toggle_fold),
    string.format("  %-6s Expand all", km.expand_all),
    string.format("  %-6s Collapse all", km.collapse_all),
    string.format("  %-6s Filter symbols", km.filter),
    string.format("  %-6s Clear filter", km.clear_filter),
    string.format("  %-6s Refresh", km.refresh),
    string.format("  %-6s Toggle view (flat/hierarchy)", km.toggle_view),
    string.format("  %-6s Show this help", km.help),
    "",
    " Press q or <Esc> to close ",
  }

  -- Create floating window
  local width = 42
  local height = #lines
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)

  -- Close on q or Escape
  local function close_help()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set("n", "q", close_help, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", close_help, { buffer = buf, nowait = true, silent = true })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = close_help,
  })
end

return M
