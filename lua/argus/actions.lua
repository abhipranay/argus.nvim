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

---Check if a symbol uses iota (const with no explicit value after first)
---@param bufnr number
---@param symbol table
---@return boolean
local function uses_iota(bufnr, symbol)
  if symbol.kind ~= "const" then
    return false
  end

  local formatter = require("argus.formatter")
  if not formatter.is_in_group(bufnr, symbol) then
    return false
  end

  local start_line, end_line = formatter.find_group_boundaries(bufnr, symbol)
  if not start_line or not end_line then
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)
  for _, line in ipairs(lines) do
    if line:match("iota") then
      return true
    end
  end

  return false
end

---Check if a symbol is at the edge of its group
---@param symbol table
---@param bufnr number
---@param direction string "up" or "down"
---@return boolean
local function is_at_group_edge(symbol, bufnr, direction)
  local formatter = require("argus.formatter")
  if not formatter.is_in_group(bufnr, symbol) then
    return false
  end

  local group_siblings, index = symbols_mod.get_group_siblings(symbol, render.get_symbols(), bufnr)
  if #group_siblings == 0 then
    return false
  end

  if direction == "up" then
    return index == 1
  else
    return index == #group_siblings
  end
end

---Convert a singleton group to standalone declaration
---e.g., "var (\n    x int\n)" becomes "var x int"
---@param bufnr number
---@param group_start number 0-indexed start line
---@param group_end number 0-indexed end line
---@param keyword string "const", "var", or "type"
local function convert_singleton_to_standalone(bufnr, group_start, group_end, keyword)
  local lines = vim.api.nvim_buf_get_lines(bufnr, group_start, group_end + 1, false)
  if #lines < 3 then
    return
  end

  -- Extract the declaration content (between opening and closing parens)
  local content_lines = {}
  for idx = 2, #lines - 1 do
    local line = vim.trim(lines[idx])
    if line ~= "" then
      table.insert(content_lines, line)
    end
  end

  if #content_lines ~= 1 then
    return -- Not a singleton, or complex multi-line
  end

  -- Create standalone declaration
  local new_line = keyword .. " " .. content_lines[1]
  vim.api.nvim_buf_set_lines(bufnr, group_start, group_end + 1, false, { new_line })
end

---Extract a symbol from its group and make it standalone
---@param bufnr number
---@param symbol table
---@param direction string "up" or "down"
---@return boolean success
local function extract_from_group(bufnr, symbol, direction)
  local formatter = require("argus.formatter")

  local group_start, group_end = formatter.find_group_boundaries(bufnr, symbol)
  if not group_start or not group_end then
    return false
  end

  local keyword = formatter.get_group_keyword(bufnr, symbol)
  if not keyword then
    return false
  end

  -- Get the symbol's lines within the group (use code_start_line, not start_line)
  local sym_start_0 = symbol.code_start_line - 1
  local sym_end_0 = symbol.end_line - 1

  -- Extract symbol content
  local sym_lines = vim.api.nvim_buf_get_lines(bufnr, sym_start_0, sym_end_0 + 1, false)

  -- Build standalone declaration
  local standalone_lines = {}
  table.insert(standalone_lines, keyword .. " " .. vim.trim(sym_lines[1]))
  for idx = 2, #sym_lines do
    table.insert(standalone_lines, sym_lines[idx])
  end

  -- Get group siblings to check if this will leave a singleton
  local group_siblings = symbols_mod.get_group_siblings(symbol, render.get_symbols(), bufnr)
  local will_be_singleton = #group_siblings == 2

  -- Delete the symbol from the group first
  -- We need to also remove any trailing blank line if present
  local delete_end = sym_end_0 + 1
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if delete_end < #all_lines and vim.trim(all_lines[delete_end + 1]) == "" then
    -- Check if next line is blank and still within group
    if delete_end < group_end then
      delete_end = delete_end + 1
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, sym_start_0, delete_end, false, {})

  -- Recalculate group boundaries after deletion
  local lines_removed = delete_end - sym_start_0
  local new_group_end = group_end - lines_removed
  local new_group_start = group_start
  if sym_start_0 < group_start then
    new_group_start = group_start - lines_removed
  end

  -- If we're extracting UP, insert before the group AND any preceding comments
  -- If we're extracting DOWN, insert after the group
  local insert_pos
  if direction == "up" then
    -- Find any comments directly preceding the group (not separated by blank lines)
    -- so the comment stays with the group
    local updated_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    insert_pos = new_group_start
    for idx = new_group_start - 1, 0, -1 do
      local line = updated_lines[idx + 1]
      local trimmed = vim.trim(line)
      if trimmed:match("^//") then
        -- Comment line - include it with the group
        insert_pos = idx
      elseif trimmed == "" then
        -- Blank line - stop here, blank lines separate logical sections
        break
      else
        -- Non-comment, non-blank line - stop
        break
      end
    end
  else
    insert_pos = new_group_end + 1
  end

  -- Add blank line separator if needed
  local lines_to_insert = {}
  if direction == "up" then
    for _, line in ipairs(standalone_lines) do
      table.insert(lines_to_insert, line)
    end
    table.insert(lines_to_insert, "")
  else
    table.insert(lines_to_insert, "")
    for _, line in ipairs(standalone_lines) do
      table.insert(lines_to_insert, line)
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, insert_pos, insert_pos, false, lines_to_insert)

  -- If we left a singleton, convert it to standalone
  if will_be_singleton then
    -- Re-parse to get updated positions
    local updated_symbols = parser.parse_buffer(bufnr)
    -- Find remaining sibling in group syntax (use is_in_group_syntax for singletons)
    for _, sym in ipairs(updated_symbols) do
      if sym.name ~= symbol.name then
        -- Use is_in_group_syntax to detect singletons (is_in_group returns false for singletons)
        if formatter.is_in_group_syntax(bufnr, sym) then
          local sym_keyword = formatter.get_group_keyword(bufnr, sym)
          if sym_keyword == keyword then
            local new_start, new_end = formatter.find_group_boundaries(bufnr, sym)
            if new_start and new_end then
              convert_singleton_to_standalone(bufnr, new_start, new_end, keyword)
              break -- Only convert one singleton
            end
          end
        end
      end
    end
  end

  return true
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

  local formatter = require("argus.formatter")
  local in_group = formatter.is_in_group(source_buf, symbol)

  -- Check for iota const groups - warn and refuse
  if in_group and uses_iota(source_buf, symbol) then
    vim.notify("argus: Cannot move items in iota const group", vim.log.levels.WARN)
    return
  end

  -- If in group and at top edge, extract from group
  if in_group and is_at_group_edge(symbol, source_buf, "up") then
    if extract_from_group(source_buf, symbol, "up") then
      -- Re-parse and re-render
      local new_symbols = parser.parse_buffer(source_buf)
      local outline_buf = window.get_outline_bufnr()
      if outline_buf then
        render.render(outline_buf, new_symbols)
      end
      -- Position cursor on moved symbol
      M._position_cursor_on_symbol(symbol.name, symbol.kind)
    end
    return
  end

  -- If in group but not at edge, swap within group
  if in_group then
    local group_siblings, group_index = symbols_mod.get_group_siblings(symbol, render.get_symbols(), source_buf)
    if group_index > 1 then
      local prev_sibling = group_siblings[group_index - 1]
      M._swap_symbols(source_buf, symbol, prev_sibling, "up")
      return
    end
  end

  -- Not in group: use regular sibling logic
  local siblings, index = symbols_mod.get_siblings(symbol, render.get_symbols())
  if index <= 1 then
    vim.notify("argus: Already at top", vim.log.levels.INFO)
    return
  end

  local prev_sibling = siblings[index - 1]

  -- Check if target sibling is in a group - if so, insert into group instead of swap
  if formatter.is_in_group(source_buf, prev_sibling) then
    M._insert_into_group(source_buf, symbol, prev_sibling, "up")
    return
  end

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

  local formatter = require("argus.formatter")
  local in_group = formatter.is_in_group(source_buf, symbol)

  -- Check for iota const groups - warn and refuse
  if in_group and uses_iota(source_buf, symbol) then
    vim.notify("argus: Cannot move items in iota const group", vim.log.levels.WARN)
    return
  end

  -- If in group and at bottom edge, extract from group
  if in_group and is_at_group_edge(symbol, source_buf, "down") then
    if extract_from_group(source_buf, symbol, "down") then
      -- Re-parse and re-render
      local new_symbols = parser.parse_buffer(source_buf)
      local outline_buf = window.get_outline_bufnr()
      if outline_buf then
        render.render(outline_buf, new_symbols)
      end
      -- Position cursor on moved symbol
      M._position_cursor_on_symbol(symbol.name, symbol.kind)
    end
    return
  end

  -- If in group but not at edge, swap within group
  if in_group then
    local group_siblings, group_index = symbols_mod.get_group_siblings(symbol, render.get_symbols(), source_buf)
    if group_index < #group_siblings then
      local next_sibling = group_siblings[group_index + 1]
      M._swap_symbols(source_buf, symbol, next_sibling, "down")
      return
    end
  end

  -- Not in group: use regular sibling logic
  local siblings, index = symbols_mod.get_siblings(symbol, render.get_symbols())
  if index >= #siblings then
    vim.notify("argus: Already at bottom", vim.log.levels.INFO)
    return
  end

  local next_sibling = siblings[index + 1]

  -- Check if target sibling is in a group - if so, insert into group instead of swap
  if formatter.is_in_group(source_buf, next_sibling) then
    M._insert_into_group(source_buf, symbol, next_sibling, "down")
    return
  end

  M._swap_symbols(source_buf, symbol, next_sibling, "down")
end

---Insert a standalone symbol into a group at the position of target
---@param source_buf number
---@param symbol Symbol The standalone symbol to insert
---@param target Symbol The symbol inside the group
---@param direction string "up" or "down"
function M._insert_into_group(source_buf, symbol, target, direction)
  local formatter = require("argus.formatter")

  -- Get the keyword from the target's group
  local keyword = formatter.get_group_keyword(source_buf, target)
  if not keyword then
    vim.notify("argus: Cannot determine group type", vim.log.levels.WARN)
    return
  end

  -- Get standalone symbol's content (including any comments above)
  local sym_start_0 = symbol.start_line - 1
  local sym_end_0 = symbol.end_line - 1
  local sym_lines = vim.api.nvim_buf_get_lines(source_buf, sym_start_0, sym_end_0 + 1, false)

  if #sym_lines == 0 then
    return
  end

  -- Find which line contains the actual code (keyword line)
  -- start_line includes comments, code_start_line is the actual declaration
  local code_offset = symbol.code_start_line - symbol.start_line -- 0-based offset within sym_lines
  local code_line_idx = code_offset + 1 -- 1-based index in sym_lines

  -- Strip the keyword from the code line (not from comments)
  -- e.g., "var a = 1" -> "a = 1"
  local code_line = sym_lines[code_line_idx]
  local stripped_code = code_line:gsub("^%s*" .. keyword .. "%s+", "")

  -- Get the indentation used by the target (to match existing style)
  local target_start_0 = target.code_start_line - 1
  local target_lines = vim.api.nvim_buf_get_lines(source_buf, target_start_0, target_start_0 + 1, false)
  local indent = ""
  if #target_lines > 0 then
    indent = target_lines[1]:match("^(%s*)") or ""
  end

  -- Build the group item content
  -- Note: We don't preserve comments above standalone symbols when inserting into group
  -- because group items typically don't have individual comments above them
  local group_content = { indent .. stripped_code }
  for idx = code_line_idx + 1, #sym_lines do
    table.insert(group_content, sym_lines[idx])
  end

  -- Determine insert position in the group
  local insert_line_0
  if direction == "up" then
    -- Insert AFTER the target (which puts it above where we were in file order)
    insert_line_0 = target.end_line
  else
    -- Insert BEFORE the target (which puts it below where we were in file order)
    insert_line_0 = target.code_start_line - 1
  end

  -- Delete the standalone symbol first (including any following blank line)
  local delete_start = sym_start_0
  local delete_end = sym_end_0 + 1
  local all_lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)

  -- Check for blank line after symbol to delete
  if delete_end < #all_lines and vim.trim(all_lines[delete_end + 1]) == "" then
    delete_end = delete_end + 1
  end

  -- Adjust insert position if it's after the delete position
  local lines_to_delete = delete_end - delete_start
  if insert_line_0 > sym_end_0 then
    insert_line_0 = insert_line_0 - lines_to_delete
  end

  -- Delete the standalone symbol
  vim.api.nvim_buf_set_lines(source_buf, delete_start, delete_end, false, {})

  -- Insert into the group
  vim.api.nvim_buf_set_lines(source_buf, insert_line_0, insert_line_0, false, group_content)

  -- Re-parse and re-render
  local new_symbols = parser.parse_buffer(source_buf)
  local outline_buf = window.get_outline_bufnr()
  if outline_buf then
    render.render(outline_buf, new_symbols)
  end

  -- Position cursor on moved symbol
  M._position_cursor_on_symbol(symbol.name, symbol.kind)
end

---Position cursor on a symbol by name and kind after re-render
---@param moved_name string
---@param moved_kind string
function M._position_cursor_on_symbol(moved_name, moved_kind)
  for _, sym in pairs(render.get_symbols()) do
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
  for idx, s in ipairs(displayed) do
    if s.name == moved_name and s.kind == moved_kind then
      set_outline_cursor_line(idx)
      return
    end
  end
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

  -- Position cursor on the moved symbol
  M._position_cursor_on_symbol(symbol.name, symbol.kind)
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
