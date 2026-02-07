-- argus.nvim symbol data structures
local M = {}

---@class Symbol
---@field name string Symbol name
---@field kind string Symbol kind ("function"|"method"|"struct"|"interface"|"const"|"var"|"type"|"package")
---@field icon string Display icon
---@field start_line number 1-indexed, includes comments
---@field end_line number 1-indexed
---@field code_start_line number Actual declaration line, excludes comments
---@field receiver string|nil For methods: receiver type name
---@field children Symbol[] Child symbols (methods under struct)
---@field parent Symbol|nil Parent symbol reference
---@field collapsed boolean Whether node is collapsed
---@field signature string|nil Function/method signature for display

---Create a new symbol
---@param opts table
---@return Symbol
function M.new(opts)
  return {
    name = opts.name or "",
    kind = opts.kind or "function",
    icon = opts.icon or "",
    start_line = opts.start_line or 0,
    end_line = opts.end_line or 0,
    code_start_line = opts.code_start_line or opts.start_line or 0,
    receiver = opts.receiver,
    children = opts.children or {},
    parent = opts.parent,
    collapsed = opts.collapsed or false,
    signature = opts.signature,
  }
end

---Get the display name for a symbol
---@param symbol Symbol
---@return string
function M.display_name(symbol)
  if symbol.kind == "method" and symbol.receiver then
    local sig = symbol.signature or ""
    return string.format("(%s) %s%s", symbol.receiver, symbol.name, sig)
  elseif symbol.kind == "method" then
    -- Interface method (no receiver)
    local sig = symbol.signature or "()"
    return symbol.name .. sig
  elseif symbol.kind == "function" then
    local sig = symbol.signature or "()"
    return symbol.name .. sig
  elseif symbol.kind == "field" then
    local type_info = symbol.signature or ""
    if type_info ~= "" then
      return symbol.name .. " " .. type_info
    end
    return symbol.name
  else
    return symbol.name
  end
end

---Check if a symbol can have children
---@param symbol Symbol
---@return boolean
function M.can_have_children(symbol)
  return symbol.kind == "struct" or symbol.kind == "interface" or symbol.kind == "type"
end

---Add a child symbol
---@param parent Symbol
---@param child Symbol
function M.add_child(parent, child)
  child.parent = parent
  table.insert(parent.children, child)
end

---Get all symbols flattened (for iteration)
---@param symbols Symbol[]
---@param include_collapsed boolean|nil Include children of collapsed nodes
---@return Symbol[]
function M.flatten(symbols, include_collapsed)
  local result = {}

  local function traverse(list)
    for _, symbol in ipairs(list) do
      table.insert(result, symbol)
      if #symbol.children > 0 and (include_collapsed or not symbol.collapsed) then
        traverse(symbol.children)
      end
    end
  end

  traverse(symbols)
  return result
end

---Find a symbol by line number in source
---@param symbols Symbol[]
---@param line number
---@return Symbol|nil
function M.find_by_source_line(symbols, line)
  local flat = M.flatten(symbols, true)
  for _, symbol in ipairs(flat) do
    if line >= symbol.start_line and line <= symbol.end_line then
      -- Return the most specific match (deepest in hierarchy)
      local best = symbol
      for _, child in ipairs(symbol.children) do
        if line >= child.start_line and line <= child.end_line then
          best = child
        end
      end
      return best
    end
  end
  return nil
end

---Get siblings at the same level
---@param symbol Symbol
---@param symbols Symbol[] Top-level symbols if no parent
---@return Symbol[], number Index of symbol in siblings
function M.get_siblings(symbol, symbols)
  local siblings
  if symbol.parent then
    siblings = symbol.parent.children
  else
    siblings = symbols
  end

  local index = 0
  for i, s in ipairs(siblings) do
    if s == symbol then
      index = i
      break
    end
  end

  return siblings, index
end

---Calculate total line count for a symbol (including children)
---@param symbol Symbol
---@return number
function M.line_count(symbol)
  return symbol.end_line - symbol.start_line + 1
end

return M
