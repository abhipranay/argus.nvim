-- argus.nvim highlight group definitions
local M = {}

-- Check if a highlight group exists and has definitions
local function hl_exists(name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return ok and hl and next(hl) ~= nil
end

-- Get the best available highlight group from a priority list
local function get_best_hl(candidates)
  for _, name in ipairs(candidates) do
    if hl_exists(name) then
      return name
    end
  end
  return candidates[#candidates] -- Fall back to last (usually a standard one)
end

---Setup highlight groups
function M.setup()
  -- Use treesitter/LSP semantic highlights if available, fall back to classic
  local highlights = {
    -- Symbol kinds - prefer treesitter highlights (@) for modern colorscheme support
    ArgusPackage = { link = get_best_hl({ "@module", "@namespace", "@lsp.type.namespace", "Keyword" }) },
    ArgusFunction = { link = get_best_hl({ "@function", "@lsp.type.function", "Function" }) },
    ArgusMethod = { link = get_best_hl({ "@function.method", "@method", "@lsp.type.method", "Function" }) },
    ArgusStruct = { link = get_best_hl({ "@type", "@lsp.type.struct", "@lsp.type.type", "Type" }) },
    ArgusInterface = { link = get_best_hl({ "@type", "@lsp.type.interface", "@lsp.type.type", "Type" }) },
    ArgusType = { link = get_best_hl({ "@type", "@lsp.type.type", "Type" }) },
    ArgusConst = { link = get_best_hl({ "@constant", "@lsp.type.enumMember", "Constant" }) },
    ArgusVar = { link = get_best_hl({ "@variable", "@lsp.type.variable", "Identifier" }) },
    ArgusField = { link = get_best_hl({ "@variable.member", "@field", "@lsp.type.property", "Identifier" }) },

    -- UI elements
    ArgusIcon = { link = get_best_hl({ "Special", "Normal" }) },
    ArgusLineNr = { link = "LineNr" },
    ArgusFoldIcon = { link = get_best_hl({ "@punctuation.bracket", "Delimiter", "Comment" }) },
    ArgusSelected = { link = "Visual" },
    ArgusFilter = { link = "Search" },

    -- Receiver in methods
    ArgusReceiver = { link = get_best_hl({ "@variable.parameter", "@parameter", "Comment" }) },
    ArgusSignature = { link = get_best_hl({ "@type", "Comment" }) },
  }

  for name, opts in pairs(highlights) do
    -- Only set if not already defined by user
    local existing = vim.api.nvim_get_hl(0, { name = name })
    if not existing or not next(existing) then
      vim.api.nvim_set_hl(0, name, opts)
    end
  end
end

---Get highlight group for a symbol kind
---@param kind string
---@return string
function M.get_hl_group(kind)
  local map = {
    package = "ArgusPackage",
    ["function"] = "ArgusFunction",
    method = "ArgusMethod",
    struct = "ArgusStruct",
    interface = "ArgusInterface",
    type = "ArgusType",
    const = "ArgusConst",
    var = "ArgusVar",
    field = "ArgusField",
  }
  return map[kind] or "Normal"
end

return M
