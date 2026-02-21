-- argus.nvim treesitter parsing module
local M = {}

local symbols = require("argus.symbols")
local config = require("argus.config")

---Get the comment range preceding a node
---@param bufnr number
---@param node_start_line number 0-indexed
---@return number|nil First comment line (0-indexed), nil if no comments
local function get_preceding_comment_start(bufnr, node_start_line)
  if node_start_line <= 0 then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, node_start_line, false)
  local comment_start = nil
  local in_block_comment = false

  -- Walk backwards from the line before the node
  for i = #lines, 1, -1 do
    local line = lines[i]
    local trimmed = vim.trim(line)

    -- Check for block comment end (*/)
    if trimmed:match("%*/$") then
      in_block_comment = true
      comment_start = i - 1 -- 0-indexed
    elseif in_block_comment then
      -- Inside block comment, look for start
      if trimmed:match("^/%*") then
        in_block_comment = false
        comment_start = i - 1
      else
        comment_start = i - 1
      end
    elseif trimmed:match("^//") then
      -- Line comment
      comment_start = i - 1
    elseif trimmed == "" then
      -- Empty line - stop if we've found comments, otherwise continue
      if comment_start then
        break
      end
    else
      -- Non-comment, non-empty line - stop
      break
    end
  end

  return comment_start
end

---Extract function/method signature
---@param node userdata Treesitter node
---@param bufnr number
---@return string
local function extract_signature(node, bufnr)
  local params_node = node:field("parameters")[1]
  if not params_node then
    return "()"
  end

  local params_text = vim.treesitter.get_node_text(params_node, bufnr)
  -- Simplify: just show (...) if too long
  if #params_text > 30 then
    return "(...)"
  end
  return params_text
end

---Extract receiver from method declaration
---@param node userdata
---@param bufnr number
---@return string|nil receiver type, string|nil receiver var
local function extract_receiver(node, bufnr)
  local receiver_node = node:field("receiver")[1]
  if not receiver_node then
    return nil, nil
  end

  -- Get the parameter inside the receiver
  for child in receiver_node:iter_children() do
    if child:type() == "parameter_declaration" then
      local type_node = child:field("type")[1]
      local name_node = child:field("name")[1]

      local receiver_var = name_node and vim.treesitter.get_node_text(name_node, bufnr) or nil
      local receiver_type = nil

      if type_node then
        local type_text = vim.treesitter.get_node_text(type_node, bufnr)
        -- Extract just the type name (handle *Type, Type, etc.)
        receiver_type = type_text:match("%*?([%w_]+)")
      end

      return receiver_type, receiver_var
    end
  end

  return nil, nil
end

---Parse a function declaration node
---@param node userdata
---@param bufnr number
---@return Symbol|nil
local function parse_function(node, bufnr)
  local name_node = node:field("name")[1]
  if not name_node then
    return nil
  end

  local name = vim.treesitter.get_node_text(name_node, bufnr)
  local start_row, _, end_row, _ = node:range()
  local comment_start = get_preceding_comment_start(bufnr, start_row)

  local cfg = config.get()
  return symbols.new({
    name = name,
    kind = "function",
    icon = cfg.icons["function"],
    start_line = (comment_start or start_row) + 1,
    end_line = end_row + 1,
    code_start_line = start_row + 1,
    signature = extract_signature(node, bufnr),
  })
end

---Parse a method declaration node
---@param node userdata
---@param bufnr number
---@return Symbol|nil, string|nil receiver_type
local function parse_method(node, bufnr)
  local name_node = node:field("name")[1]
  if not name_node then
    return nil, nil
  end

  local name = vim.treesitter.get_node_text(name_node, bufnr)
  local receiver_type, receiver_var = extract_receiver(node, bufnr)
  if not receiver_type then
    return nil, nil
  end

  local start_row, _, end_row, _ = node:range()
  local comment_start = get_preceding_comment_start(bufnr, start_row)

  local cfg = config.get()
  local receiver_display
  if receiver_var then
    receiver_display = receiver_var .. " *" .. receiver_type
  else
    receiver_display = "*" .. receiver_type
  end

  return symbols.new({
    name = name,
    kind = "method",
    icon = cfg.icons.method,
    start_line = (comment_start or start_row) + 1,
    end_line = end_row + 1,
    code_start_line = start_row + 1,
    receiver = receiver_display,
    signature = extract_signature(node, bufnr),
  }), receiver_type
end

---Parse struct fields
---@param struct_node userdata The struct_type node
---@param bufnr number
---@return Symbol[]
local function parse_struct_fields(struct_node, bufnr)
  local fields = {}
  local cfg = config.get()

  for child in struct_node:iter_children() do
    if child:type() == "field_declaration_list" then
      for field in child:iter_children() do
        if field:type() == "field_declaration" then
          local name_node = field:field("name")[1]
          local type_node = field:field("type")[1]

          if name_node then
            local name = vim.treesitter.get_node_text(name_node, bufnr)
            local type_text = type_node and vim.treesitter.get_node_text(type_node, bufnr) or ""
            local start_row, _, end_row, _ = field:range()

            table.insert(fields, symbols.new({
              name = name,
              kind = "field",
              icon = cfg.icons.field or "󰜢",
              start_line = start_row + 1,
              end_line = end_row + 1,
              code_start_line = start_row + 1,
              signature = type_text,
            }))
          end
        end
      end
    end
  end

  return fields
end

---Parse interface methods
---@param interface_node userdata The interface_type node
---@param bufnr number
---@return Symbol[]
local function parse_interface_methods(interface_node, bufnr)
  local methods = {}
  local cfg = config.get()

  for child in interface_node:iter_children() do
    if child:type() == "method_spec" then
      local name_node = child:field("name")[1]
      local params_node = child:field("parameters")[1]

      if name_node then
        local name = vim.treesitter.get_node_text(name_node, bufnr)
        local params_text = params_node and vim.treesitter.get_node_text(params_node, bufnr) or "()"
        local start_row, _, end_row, _ = child:range()

        if #params_text > 30 then
          params_text = "(...)"
        end

        table.insert(methods, symbols.new({
          name = name,
          kind = "method",
          icon = cfg.icons.method,
          start_line = start_row + 1,
          end_line = end_row + 1,
          code_start_line = start_row + 1,
          signature = params_text,
        }))
      end
    end
  end

  return methods
end

---Parse a single type_spec node
---@param type_spec userdata
---@param bufnr number
---@param comment_start number|nil
---@return Symbol|nil
local function parse_type_spec(type_spec, bufnr, comment_start)
  local name_node = type_spec:field("name")[1]
  local type_node = type_spec:field("type")[1]

  if not name_node or not type_node then
    return nil
  end

  local name = vim.treesitter.get_node_text(name_node, bufnr)
  local type_kind = type_node:type()
  local start_row, _, end_row, _ = type_spec:range()

  local cfg = config.get()
  local kind, icon

  if type_kind == "struct_type" then
    kind = "struct"
    icon = cfg.icons.struct
  elseif type_kind == "interface_type" then
    kind = "interface"
    icon = cfg.icons.interface
  else
    kind = "type"
    icon = cfg.icons.type
  end

  local symbol = symbols.new({
    name = name,
    kind = kind,
    icon = icon,
    start_line = (comment_start or start_row) + 1,
    end_line = end_row + 1,
    code_start_line = start_row + 1,
  })

  -- Parse children (fields for struct, methods for interface)
  if type_kind == "struct_type" then
    local fields = parse_struct_fields(type_node, bufnr)
    for _, field in ipairs(fields) do
      symbols.add_child(symbol, field)
    end
  elseif type_kind == "interface_type" then
    local iface_methods = parse_interface_methods(type_node, bufnr)
    for _, method in ipairs(iface_methods) do
      symbols.add_child(symbol, method)
    end
  end

  return symbol
end

---Parse a type declaration (handles both single and grouped declarations)
---@param node userdata
---@param bufnr number
---@return Symbol[]
local function parse_type_declaration(node, bufnr)
  local result = {}
  local start_row, _, _, _ = node:range()
  local group_comment_start = get_preceding_comment_start(bufnr, start_row)

  for child in node:iter_children() do
    if child:type() == "type_spec" then
      -- Look for comment above this specific type spec
      local spec_start, _, _, _ = child:range()
      local spec_comment = get_preceding_comment_start(bufnr, spec_start)
      -- Use spec's own comment if found, otherwise use group's comment for first item
      local comment_start = spec_comment or group_comment_start
      local symbol = parse_type_spec(child, bufnr, comment_start)
      if symbol then
        table.insert(result, symbol)
      end
      -- Only first item can use group's comment
      group_comment_start = nil
    end
  end

  return result
end

---Parse const declaration
---@param node userdata
---@param bufnr number
---@return Symbol[]
local function parse_const_declaration(node, bufnr)
  local result = {}
  local cfg = config.get()
  local start_row, _, end_row, _ = node:range()
  local group_comment_start = get_preceding_comment_start(bufnr, start_row)

  for child in node:iter_children() do
    if child:type() == "const_spec" then
      local name_node = child:field("name")[1]
      if name_node then
        local name = vim.treesitter.get_node_text(name_node, bufnr)
        local spec_start, _, spec_end, _ = child:range()
        -- Look for comment above this specific spec
        local spec_comment = get_preceding_comment_start(bufnr, spec_start)
        -- Use spec's own comment if found, otherwise use group's comment for first item
        local comment_start = spec_comment or group_comment_start
        table.insert(result, symbols.new({
          name = name,
          kind = "const",
          icon = cfg.icons.const,
          start_line = (comment_start or spec_start) + 1,
          end_line = spec_end + 1,
          code_start_line = spec_start + 1,
        }))
        -- Only first item can use group's comment
        group_comment_start = nil
      end
    end
  end

  return result
end

---Parse a single var_spec node
---@param spec userdata
---@param bufnr number
---@param cfg table
---@param comment_start number|nil
---@return Symbol|nil, nil
local function parse_var_spec(spec, bufnr, cfg, comment_start)
  local name_node = spec:field("name")[1]
  if name_node then
    local name = vim.treesitter.get_node_text(name_node, bufnr)
    local spec_start, _, spec_end, _ = spec:range()
    return symbols.new({
      name = name,
      kind = "var",
      icon = cfg.icons.var,
      start_line = (comment_start or spec_start) + 1,
      end_line = spec_end + 1,
      code_start_line = spec_start + 1,
    })
  end
  return nil
end

---Parse var declaration
---@param node userdata
---@param bufnr number
---@return Symbol[]
local function parse_var_declaration(node, bufnr)
  local result = {}
  local cfg = config.get()
  local start_row, _, end_row, _ = node:range()
  local comment_start = get_preceding_comment_start(bufnr, start_row)

  for child in node:iter_children() do
    if child:type() == "var_spec" then
      -- Direct var_spec (single var declaration)
      local sym = parse_var_spec(child, bufnr, cfg, comment_start)
      if sym then
        table.insert(result, sym)
        comment_start = nil
      end
    elseif child:type() == "var_spec_list" then
      -- Grouped var declaration - check for comments above each spec
      for spec in child:iter_children() do
        if spec:type() == "var_spec" then
          -- Look for comment above this specific spec
          local spec_start, _, _, _ = spec:range()
          local spec_comment = get_preceding_comment_start(bufnr, spec_start)
          -- Use spec's own comment if found, otherwise use group's comment for first item
          local sym = parse_var_spec(spec, bufnr, cfg, spec_comment or comment_start)
          if sym then
            table.insert(result, sym)
            comment_start = nil -- Only first item can use group's comment
          end
        end
      end
    end
  end

  return result
end

---Parse package clause
---@param node userdata
---@param bufnr number
---@return Symbol
local function parse_package(node, bufnr)
  local cfg = config.get()
  local start_row, _, end_row, _ = node:range()
  local comment_start = get_preceding_comment_start(bufnr, start_row)

  -- Get package name
  local name = "main"
  for child in node:iter_children() do
    if child:type() == "package_identifier" then
      name = vim.treesitter.get_node_text(child, bufnr)
      break
    end
  end

  return symbols.new({
    name = name,
    kind = "package",
    icon = cfg.icons.package,
    start_line = (comment_start or start_row) + 1,
    end_line = end_row + 1,
    code_start_line = start_row + 1,
  })
end

---Parse buffer and extract all symbols
---@param bufnr number|nil Buffer number (nil for current)
---@param view_mode string|nil "flat" or "hierarchy" (default from config)
---@return Symbol[]
function M.parse_buffer(bufnr, view_mode)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  view_mode = view_mode or config.get().view_mode or "flat"

  -- Check if buffer has Go filetype
  local ft = vim.bo[bufnr].filetype
  if ft ~= "go" then
    return {}
  end

  -- Get treesitter parser
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "go")
  if not ok or not parser then
    vim.notify("argus: Go treesitter parser not available", vim.log.levels.WARN)
    return {}
  end

  local tree = parser:parse()[1]
  if not tree then
    return {}
  end

  local root = tree:root()
  local result = {}
  local type_map = {} -- Map type names to their symbols for method grouping
  local methods = {} -- Collect methods to attach later

  -- First pass: collect all declarations
  for node in root:iter_children() do
    local node_type = node:type()

    if node_type == "package_clause" then
      table.insert(result, parse_package(node, bufnr))
    elseif node_type == "function_declaration" then
      local symbol = parse_function(node, bufnr)
      if symbol then
        table.insert(result, symbol)
      end
    elseif node_type == "method_declaration" then
      local symbol, receiver_type = parse_method(node, bufnr)
      if symbol and receiver_type then
        if view_mode == "flat" then
          -- In flat mode, add methods directly to result
          table.insert(result, symbol)
        else
          -- In hierarchy mode, collect for later attachment
          table.insert(methods, { symbol = symbol, receiver_type = receiver_type })
        end
      end
    elseif node_type == "type_declaration" then
      -- Now returns multiple symbols for grouped declarations
      local type_symbols = parse_type_declaration(node, bufnr)
      for _, symbol in ipairs(type_symbols) do
        table.insert(result, symbol)
        type_map[symbol.name] = symbol
      end
    elseif node_type == "const_declaration" then
      local consts = parse_const_declaration(node, bufnr)
      for _, c in ipairs(consts) do
        table.insert(result, c)
      end
    elseif node_type == "var_declaration" then
      local vars = parse_var_declaration(node, bufnr)
      for _, v in ipairs(vars) do
        table.insert(result, v)
      end
    end
  end

  -- Second pass: attach methods to their receiver types (only in hierarchy mode)
  if view_mode == "hierarchy" then
    for _, m in ipairs(methods) do
      local parent = type_map[m.receiver_type]
      if parent then
        symbols.add_child(parent, m.symbol)
      else
        -- Orphan method (receiver type not in this file)
        table.insert(result, m.symbol)
      end
    end
  end

  -- Sort by start_line to maintain file order
  table.sort(result, function(a, b)
    return a.start_line < b.start_line
  end)

  -- Sort children by start_line
  for _, symbol in ipairs(result) do
    if #symbol.children > 0 then
      table.sort(symbol.children, function(a, b)
        return a.start_line < b.start_line
      end)
    end
  end

  return result
end

---Get symbol at a specific line in outline
---@param symbols_list Symbol[]
---@param outline_line number Line in outline buffer (1-indexed)
---@return Symbol|nil
function M.get_symbol_at_outline_line(symbols_list, outline_line)
  local flat = symbols.flatten(symbols_list, false)
  if outline_line >= 1 and outline_line <= #flat then
    return flat[outline_line]
  end
  return nil
end

return M
