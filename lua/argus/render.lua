-- argus.nvim rendering module
local M = {}

local config = require("argus.config")
local symbols_mod = require("argus.symbols")
local highlights = require("argus.highlights")

-- State for tracking line-to-symbol mapping
local line_map = {}
local current_symbols = {}

---Get the symbols currently being displayed
---@return Symbol[]
function M.get_symbols()
  return current_symbols
end

---Get symbol at a specific outline line
---@param line number 1-indexed line number
---@return Symbol|nil
function M.get_symbol_at_line(line)
  return line_map[line]
end

---Get the outline line for a symbol
---@param symbol Symbol
---@return number|nil
function M.get_line_for_symbol(symbol)
  for line, sym in pairs(line_map) do
    if sym == symbol then
      return line
    end
  end
  return nil
end

---Render a single symbol line
---@param symbol Symbol
---@param indent number Indentation level
---@param cfg ArgusConfig
---@return string line, table[] highlights
local function render_symbol_line(symbol, indent, cfg)
  local parts = {}
  local hl_ranges = {}
  local col = 0

  -- Indentation
  local indent_str = string.rep("  ", indent)
  table.insert(parts, indent_str)
  col = col + #indent_str

  -- Fold indicator for symbols with children
  if #symbol.children > 0 then
    local fold_kind = symbol.collapsed and "collapsed" or "expanded"
    local fold_icon, fold_hl = config.get_icon_with_hl(fold_kind)
    -- get_icon_with_hl already handles fallback for collapsed/expanded
    table.insert(parts, fold_icon .. " ")
    table.insert(hl_ranges, { group = fold_hl or "ArgusFoldIcon", col = col, length = #fold_icon })
    col = col + #fold_icon + 1
  end

  -- Icon (with mini.icons support)
  local icon, icon_hl = config.get_icon_with_hl(symbol.kind)
  -- get_icon_with_hl already handles fallback
  table.insert(parts, icon .. " ")
  table.insert(hl_ranges, { group = icon_hl or "ArgusIcon", col = col, length = #icon })
  col = col + #icon + 1

  -- Symbol name (with special handling for fields to show type separately)
  local name_hl = highlights.get_hl_group(symbol.kind)

  if symbol.kind == "field" then
    -- For fields: show name and type with different highlights
    table.insert(parts, symbol.name)
    table.insert(hl_ranges, { group = name_hl, col = col, length = #symbol.name })
    col = col + #symbol.name

    if symbol.signature and symbol.signature ~= "" then
      local type_str = " " .. symbol.signature
      table.insert(parts, type_str)
      table.insert(hl_ranges, { group = "ArgusSignature", col = col, length = #type_str })
      col = col + #type_str
    end
  else
    local display = symbols_mod.display_name(symbol)
    table.insert(parts, display)
    table.insert(hl_ranges, { group = name_hl, col = col, length = #display })
    col = col + #display
  end

  -- Line number (optional)
  if cfg.show_line_numbers then
    local line_nr = string.format(" :%d", symbol.code_start_line)
    table.insert(parts, line_nr)
    table.insert(hl_ranges, { group = "ArgusLineNr", col = col, length = #line_nr })
  end

  return table.concat(parts), hl_ranges
end

---Build display lines from symbols
---@param symbols_list Symbol[]
---@param filter_pattern string|nil Optional filter pattern
---@return string[] lines, table<number, Symbol> line_to_symbol, table[] all_highlights
local function build_lines(symbols_list, filter_pattern)
  local lines = {}
  local line_to_symbol = {}
  local all_highlights = {}
  local cfg = config.get()

  ---Check if symbol matches filter
  ---@param symbol Symbol
  ---@return boolean
  local function matches_filter(symbol)
    if not filter_pattern or filter_pattern == "" then
      return true
    end
    local pattern = filter_pattern:lower()
    if symbol.name:lower():find(pattern, 1, true) then
      return true
    end
    -- Check children
    for _, child in ipairs(symbol.children) do
      if matches_filter(child) then
        return true
      end
    end
    return false
  end

  ---Recursively render symbols
  ---@param list Symbol[]
  ---@param indent number
  local function render_recursive(list, indent)
    for _, symbol in ipairs(list) do
      if matches_filter(symbol) then
        local line_num = #lines + 1
        local line_text, hl_ranges = render_symbol_line(symbol, indent, cfg)

        table.insert(lines, line_text)
        line_to_symbol[line_num] = symbol

        -- Store highlights for this line
        for _, hl in ipairs(hl_ranges) do
          table.insert(all_highlights, {
            line = line_num - 1, -- 0-indexed for nvim_buf_add_highlight
            group = hl.group,
            col = hl.col,
            length = hl.length,
          })
        end

        -- Render children if not collapsed
        if #symbol.children > 0 and not symbol.collapsed then
          render_recursive(symbol.children, indent + 1)
        end
      end
    end
  end

  render_recursive(symbols_list, 0)

  return lines, line_to_symbol, all_highlights
end

---Render symbols to the outline buffer
---@param bufnr number Outline buffer
---@param symbols_list Symbol[]
---@param filter_pattern string|nil
function M.render(bufnr, symbols_list, filter_pattern)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  current_symbols = symbols_list
  local lines, new_line_map, all_highlights = build_lines(symbols_list, filter_pattern)
  line_map = new_line_map

  -- Make buffer modifiable temporarily
  vim.bo[bufnr].modifiable = true

  -- Clear and set lines
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)

  -- Apply highlights
  local ns = vim.api.nvim_create_namespace("argus")
  for _, hl in ipairs(all_highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, ns, hl.group, hl.line, hl.col, hl.col + hl.length)
  end

  -- Make buffer non-modifiable again
  vim.bo[bufnr].modifiable = false
end

---Find the outline line that best matches a source line
---@param source_line number
---@return number|nil outline_line
function M.find_outline_line_for_source(source_line)
  local best_match = nil
  local best_line = nil

  for line, symbol in pairs(line_map) do
    if source_line >= symbol.start_line and source_line <= symbol.end_line then
      -- Prefer the most specific match (smallest range)
      if not best_match or (symbol.end_line - symbol.start_line) < (best_match.end_line - best_match.start_line) then
        best_match = symbol
        best_line = line
      end
    end
  end

  return best_line
end

---Clear rendering state
function M.clear()
  line_map = {}
  current_symbols = {}
end

return M
