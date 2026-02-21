-- argus.nvim file formatting module
local M = {}

local parser = require("argus.parser")
local config = require("argus.config")

---Check if a name is public (starts with uppercase)
---@param name string
---@return boolean
function M.is_public(name)
  if not name or name == "" then
    return false
  end
  local first_char = name:sub(1, 1)
  return first_char:match("[A-Z]") ~= nil
end

---Check if a function is a constructor for one of the known types
---@param name string Function name
---@param type_names table<string, boolean> Map of type names
---@return boolean
function M.is_constructor(name, type_names)
  if not name or not type_names then
    return false
  end
  -- Match NewXxx, NewXxxFromYyy, NewXxxWithZzz, etc.
  local type_name = name:match("^New([A-Z][%w_]*)")
  if not type_name then
    return false
  end
  -- Check if the base type exists (NewFoo -> Foo, NewFooFromBar -> Foo)
  for known_type, _ in pairs(type_names) do
    if type_name == known_type or type_name:match("^" .. known_type) then
      return true
    end
  end
  return false
end

---Get the type name which this function constructs
---@param name string Function name
---@param type_names table<string, boolean> Map of type names
---@return string|nil
local function get_constructed_type(name, type_names)
  local type_name = name:match("^New([A-Z][%w_]*)")
  if not type_name then
    return nil
  end
  for known_type, _ in pairs(type_names) do
    if type_name == known_type or type_name:match("^" .. known_type) then
      return known_type
    end
  end
  return nil
end

---Extract receiver type from receiver string
---@param receiver string|nil e.g. "f *Foo" or "f Foo"
---@return string|nil
function M.get_receiver_type(receiver)
  if not receiver then
    return nil
  end
  -- Match last word (type name) from patterns like "f *Foo" or "f Foo"
  return receiver:match("([%w_]+)$")
end

---Extract source lines for a symbol (including comments)
---@param bufnr number
---@param symbol table
---@return string[]
local function extract_symbol_source(bufnr, symbol)
  local start_line = symbol.start_line - 1 -- Convert to 0-indexed
  local end_line = symbol.end_line -- Keep as 1-indexed for nvim_buf_get_lines
  return vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
end

---Find the end of header (package + imports)
---@param bufnr number
---@return number 0-indexed line after header
local function find_header_end(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local header_end = 0
  local in_import = false
  local paren_depth = 0

  for idx, line in ipairs(lines) do
    local trimmed = vim.trim(line)

    if trimmed:match("^package%s") then
      header_end = idx
    elseif trimmed:match("^import%s*%(") then
      in_import = true
      paren_depth = 1
      header_end = idx
    elseif trimmed:match("^import%s") and not trimmed:match("%(") then
      -- Single import without parens
      header_end = idx
    elseif in_import then
      if trimmed:match("%(") then
        paren_depth = paren_depth + 1
      end
      if trimmed:match("%)") then
        paren_depth = paren_depth - 1
        if paren_depth == 0 then
          in_import = false
          header_end = idx
        end
      else
        header_end = idx
      end
    end
  end

  return header_end
end

---Check if a symbol is in a grouped declaration (const, var, or type group)
---Uses treesitter to determine if the declaration is grouped
---@param bufnr number
---@param symbol table
---@return boolean
local function is_in_group(bufnr, symbol)
  if symbol.kind ~= "const" and symbol.kind ~= "var"
      and symbol.kind ~= "struct" and symbol.kind ~= "interface" and symbol.kind ~= "type" then
    return false
  end

  -- Use treesitter to find if this declaration is inside a group
  local ok, tsparser = pcall(vim.treesitter.get_parser, bufnr, "go")
  if not ok or not tsparser then
    return false
  end

  local tree = tsparser:parse()[1]
  if not tree then
    return false
  end

  local root = tree:root()
  local code_line_0 = symbol.code_start_line - 1 -- Convert to 0-indexed

  -- Find the declaration node that contains this symbol's line
  for node in root:iter_children() do
    local node_type = node:type()
    local start_row, _, end_row, _ = node:range()

    -- Check if our symbol's line falls within this node
    if code_line_0 >= start_row and code_line_0 <= end_row then
      if node_type == "const_declaration" or node_type == "var_declaration" or node_type == "type_declaration" then
        -- Count how many specs are in this declaration
        local spec_count = 0
        for child in node:iter_children() do
          if child:type() == "const_spec" or child:type() == "var_spec" or child:type() == "type_spec" then
            spec_count = spec_count + 1
          elseif child:type() == "var_spec_list" then
            -- For var groups, count specs inside the list
            for spec in child:iter_children() do
              if spec:type() == "var_spec" then
                spec_count = spec_count + 1
              end
            end
          end
        end
        -- It's a group if there's more than one spec
        return spec_count > 1
      end
    end
  end

  return false
end

---Find group boundaries for a symbol
---@param bufnr number
---@param symbol table
---@return number|nil start_line (0-indexed), number|nil end_line (0-indexed)
local function find_group_boundaries(bufnr, symbol)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local code_line = symbol.code_start_line - 1 -- 0-indexed

  -- Find the opening (const/var/type with paren)
  local start_line = nil
  for idx = code_line, 0, -1 do
    local line = lines[idx + 1]
    if line:match("^%s*const%s*%(") or line:match("^%s*var%s*%(") or line:match("^%s*type%s*%(") then
      start_line = idx
      break
    end
  end

  if not start_line then
    return nil, nil
  end

  -- Find the closing paren
  local paren_depth = 0
  local end_line = nil
  for idx = start_line, #lines - 1 do
    local line = lines[idx + 1]
    for _ in line:gmatch("%(") do
      paren_depth = paren_depth + 1
    end
    for _ in line:gmatch("%)") do
      paren_depth = paren_depth - 1
      if paren_depth == 0 then
        end_line = idx
        break
      end
    end
    if end_line then
      break
    end
  end

  return start_line, end_line
end

---Parse and sort items within a group block
---@param bufnr number
---@param start_line number 0-indexed
---@param end_line number 0-indexed
---@return string[] Sorted group lines
local function sort_group_items(bufnr, start_line, end_line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)
  if #lines < 2 then
    return lines
  end

  -- First line is "const (" or similar, last is ")"
  local header = lines[1]
  local footer = lines[#lines]

  -- Extract items between header and footer
  local items = {}
  local current_item = {}
  local current_name = nil

  for idx = 2, #lines - 1 do
    local line = lines[idx]
    local trimmed = vim.trim(line)

    if trimmed == "" then
      -- Empty line - if we have a current item, save it
      if current_name then
        table.insert(items, { name = current_name, lines = current_item })
        current_item = {}
        current_name = nil
      end
    else
      -- Check if this is a new item (name = value or name type)
      local name = trimmed:match("^([%w_]+)%s*=") or trimmed:match("^([%w_]+)%s+[%w*%[%]]")

      if name and #current_item > 0 and current_name then
        -- Save previous item and start new one
        table.insert(items, { name = current_name, lines = current_item })
        current_item = { line }
        current_name = name
      elseif name and not current_name then
        -- Start of first or new item
        current_name = name
        table.insert(current_item, line)
      else
        -- Continuation of current item (multi-line struct, comment, etc.)
        table.insert(current_item, line)
      end
    end
  end

  -- Don't forget the last item
  if current_name then
    table.insert(items, { name = current_name, lines = current_item })
  end

  -- Sort items by name
  table.sort(items, function(a, b)
    return a.name < b.name
  end)

  -- Reconstruct the group
  local result = { header }
  for _, item in ipairs(items) do
    for _, line in ipairs(item.lines) do
      table.insert(result, line)
    end
  end
  table.insert(result, footer)

  return result
end

---Categorize symbols by section according to template
---@param symbols table[]
---@param type_names table<string, boolean>
---@param standalone_types table<string, boolean>
---@return table<string, table[]>
local function categorize_symbols(symbols, type_names, standalone_types)
  local categories = {
    consts = {},
    vars = {},
    types = {},
    constructors = {},
    public_methods = {},
    private_methods = {},
    public_functions = {},
    private_functions = {},
  }

  for _, symbol in ipairs(symbols) do
    if symbol.kind == "package" then
      -- Skip - handled separately
    elseif symbol.kind == "const" then
      table.insert(categories.consts, symbol)
    elseif symbol.kind == "var" then
      table.insert(categories.vars, symbol)
    elseif symbol.kind == "struct" or symbol.kind == "interface" or symbol.kind == "type" then
      table.insert(categories.types, symbol)
    elseif symbol.kind == "method" then
      local receiver_type = M.get_receiver_type(symbol.receiver)
      if receiver_type and standalone_types[receiver_type] then
        -- Method for standalone type - will be attached to type
        -- Skip here, handled when processing standalone types
      elseif M.is_public(symbol.name) then
        table.insert(categories.public_methods, symbol)
      else
        table.insert(categories.private_methods, symbol)
      end
    elseif symbol.kind == "function" then
      if M.is_constructor(symbol.name, type_names) then
        local constructed_type = get_constructed_type(symbol.name, type_names)
        if constructed_type and standalone_types[constructed_type] then
          -- Constructor for standalone type - will be attached to type
          -- Skip here
        else
          table.insert(categories.constructors, symbol)
        end
      elseif M.is_public(symbol.name) then
        table.insert(categories.public_functions, symbol)
      else
        table.insert(categories.private_functions, symbol)
      end
    end
  end

  return categories
end

---Sort symbols alphabetically by name
---@param symbols table[]
local function sort_by_name(symbols)
  table.sort(symbols, function(a, b)
    return a.name < b.name
  end)
end

---Find methods for a specific type
---@param symbols table[]
---@param type_name string
---@return table[] methods
local function find_methods_for_type(symbols, type_name)
  local methods = {}
  for _, symbol in ipairs(symbols) do
    if symbol.kind == "method" then
      local receiver_type = M.get_receiver_type(symbol.receiver)
      if receiver_type == type_name then
        table.insert(methods, symbol)
      end
    end
  end
  return methods
end

---Find constructors for a specific type
---@param symbols table[]
---@param type_name string
---@param type_names table<string, boolean>
---@return table[] constructors
local function find_constructors_for_type(symbols, type_name, type_names)
  local constructors = {}
  for _, symbol in ipairs(symbols) do
    if symbol.kind == "function" then
      local constructed_type = get_constructed_type(symbol.name, type_names)
      if constructed_type == type_name then
        table.insert(constructors, symbol)
      end
    end
  end
  return constructors
end

---Format the buffer according to template
---@param bufnr number|nil
function M.format_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Check if buffer has Go filetype
  local ft = vim.bo[bufnr].filetype
  if ft ~= "go" then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #lines == 0 or (#lines == 1 and lines[1] == "") then
    return
  end

  -- Get config template
  local cfg = config.get()
  local template = cfg.format_template or {
    "package",
    "imports",
    "consts",
    "vars",
    "types",
    "constructors",
    "public_methods",
    "private_methods",
    "public_functions",
    "private_functions",
  }

  -- Parse the buffer
  local symbols = parser.parse_buffer(bufnr, "flat")
  if #symbols == 0 then
    return
  end

  -- Collect type names
  local type_names = {}
  local standalone_types = {}
  local grouped_types = {}

  for _, symbol in ipairs(symbols) do
    if symbol.kind == "struct" or symbol.kind == "interface" or symbol.kind == "type" then
      type_names[symbol.name] = true
      if is_in_group(bufnr, symbol) then
        grouped_types[symbol.name] = true
      else
        standalone_types[symbol.name] = true
      end
    end
  end

  -- Find and process grouped declarations first
  local processed_groups = {}
  local group_content = {} -- Map from start_line to sorted content

  for _, symbol in ipairs(symbols) do
    if (symbol.kind == "const" or symbol.kind == "var" or symbol.kind == "struct"
        or symbol.kind == "interface" or symbol.kind == "type") then
      if is_in_group(bufnr, symbol) then
        local start_line, end_line = find_group_boundaries(bufnr, symbol)
        if start_line and end_line and not processed_groups[start_line] then
          processed_groups[start_line] = true
          group_content[start_line] = {
            lines = sort_group_items(bufnr, start_line, end_line),
            end_line = end_line,
            kind = symbol.kind == "const" and "const" or (symbol.kind == "var" and "var" or "type"),
          }
        end
      end
    end
  end

  -- Extract header (package + imports)
  local header_end = find_header_end(bufnr)
  local header_lines = vim.api.nvim_buf_get_lines(bufnr, 0, header_end, false)

  -- Categorize remaining symbols
  local categories = categorize_symbols(symbols, type_names, standalone_types)

  -- Sort each category
  for _, cat_symbols in pairs(categories) do
    sort_by_name(cat_symbols)
  end

  -- Build output
  local output = {}

  -- Add header
  for _, line in ipairs(header_lines) do
    table.insert(output, line)
  end

  -- Track what we've already added
  local added_groups = {}

  -- Process each section according to template
  for _, section in ipairs(template) do
    local section_lines = {}

    if section == "package" or section == "imports" then
      -- Already in header
    elseif section == "consts" then
      -- Add const groups first
      for start_line, group_info in pairs(group_content) do
        if group_info.kind == "const" and not added_groups[start_line] then
          added_groups[start_line] = true
          if #section_lines > 0 then
            table.insert(section_lines, "")
          end
          for _, line in ipairs(group_info.lines) do
            table.insert(section_lines, line)
          end
        end
      end
      -- Add standalone consts
      for _, symbol in ipairs(categories.consts) do
        if not is_in_group(bufnr, symbol) then
          if #section_lines > 0 then
            table.insert(section_lines, "")
          end
          local src = extract_symbol_source(bufnr, symbol)
          for _, line in ipairs(src) do
            table.insert(section_lines, line)
          end
        end
      end
    elseif section == "vars" then
      -- Add var groups first
      for start_line, group_info in pairs(group_content) do
        if group_info.kind == "var" and not added_groups[start_line] then
          added_groups[start_line] = true
          if #section_lines > 0 then
            table.insert(section_lines, "")
          end
          for _, line in ipairs(group_info.lines) do
            table.insert(section_lines, line)
          end
        end
      end
      -- Add standalone vars
      for _, symbol in ipairs(categories.vars) do
        if not is_in_group(bufnr, symbol) then
          if #section_lines > 0 then
            table.insert(section_lines, "")
          end
          local src = extract_symbol_source(bufnr, symbol)
          for _, line in ipairs(src) do
            table.insert(section_lines, line)
          end
        end
      end
    elseif section == "types" then
      -- Add type groups first
      for start_line, group_info in pairs(group_content) do
        if group_info.kind == "type" and not added_groups[start_line] then
          added_groups[start_line] = true
          if #section_lines > 0 then
            table.insert(section_lines, "")
          end
          for _, line in ipairs(group_info.lines) do
            table.insert(section_lines, line)
          end
        end
      end
      -- Add standalone types with their methods attached
      for _, symbol in ipairs(categories.types) do
        if standalone_types[symbol.name] then
          if #section_lines > 0 then
            table.insert(section_lines, "")
          end
          -- Add the type
          local src = extract_symbol_source(bufnr, symbol)
          for _, line in ipairs(src) do
            table.insert(section_lines, line)
          end

          -- Add constructors for this type
          local type_constructors = find_constructors_for_type(symbols, symbol.name, type_names)
          sort_by_name(type_constructors)
          for _, ctor in ipairs(type_constructors) do
            table.insert(section_lines, "")
            local ctor_src = extract_symbol_source(bufnr, ctor)
            for _, line in ipairs(ctor_src) do
              table.insert(section_lines, line)
            end
          end

          -- Add public methods
          local type_methods = find_methods_for_type(symbols, symbol.name)
          local public_methods = {}
          local private_methods = {}
          for _, method in ipairs(type_methods) do
            if M.is_public(method.name) then
              table.insert(public_methods, method)
            else
              table.insert(private_methods, method)
            end
          end
          sort_by_name(public_methods)
          sort_by_name(private_methods)

          for _, method in ipairs(public_methods) do
            table.insert(section_lines, "")
            local method_src = extract_symbol_source(bufnr, method)
            for _, line in ipairs(method_src) do
              table.insert(section_lines, line)
            end
          end

          for _, method in ipairs(private_methods) do
            table.insert(section_lines, "")
            local method_src = extract_symbol_source(bufnr, method)
            for _, line in ipairs(method_src) do
              table.insert(section_lines, line)
            end
          end
        end
      end
    elseif section == "constructors" then
      -- Constructors for types in groups only
      for _, symbol in ipairs(categories.constructors) do
        if #section_lines > 0 then
          table.insert(section_lines, "")
        end
        local src = extract_symbol_source(bufnr, symbol)
        for _, line in ipairs(src) do
          table.insert(section_lines, line)
        end
      end
    elseif section == "public_methods" then
      for _, symbol in ipairs(categories.public_methods) do
        if #section_lines > 0 then
          table.insert(section_lines, "")
        end
        local src = extract_symbol_source(bufnr, symbol)
        for _, line in ipairs(src) do
          table.insert(section_lines, line)
        end
      end
    elseif section == "private_methods" then
      for _, symbol in ipairs(categories.private_methods) do
        if #section_lines > 0 then
          table.insert(section_lines, "")
        end
        local src = extract_symbol_source(bufnr, symbol)
        for _, line in ipairs(src) do
          table.insert(section_lines, line)
        end
      end
    elseif section == "public_functions" then
      for _, symbol in ipairs(categories.public_functions) do
        if #section_lines > 0 then
          table.insert(section_lines, "")
        end
        local src = extract_symbol_source(bufnr, symbol)
        for _, line in ipairs(src) do
          table.insert(section_lines, line)
        end
      end
    elseif section == "private_functions" then
      for _, symbol in ipairs(categories.private_functions) do
        if #section_lines > 0 then
          table.insert(section_lines, "")
        end
        local src = extract_symbol_source(bufnr, symbol)
        for _, line in ipairs(src) do
          table.insert(section_lines, line)
        end
      end
    end

    -- Add section to output with blank line separator
    if #section_lines > 0 then
      if #output > 0 and output[#output] ~= "" then
        table.insert(output, "")
      end
      for _, line in ipairs(section_lines) do
        table.insert(output, line)
      end
    end
  end

  -- Remove trailing empty lines
  while #output > 0 and output[#output] == "" do
    table.remove(output)
  end

  -- Replace buffer content
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output)
end

return M
