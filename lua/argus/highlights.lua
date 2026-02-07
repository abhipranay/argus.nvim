-- argus.nvim highlight group definitions
local M = {}

---Setup highlight groups
function M.setup()
  local highlights = {
    -- Symbol kinds
    ArgusPackage = { link = "Keyword" },
    ArgusFunction = { link = "Function" },
    ArgusMethod = { link = "Function" },
    ArgusStruct = { link = "Type" },
    ArgusInterface = { link = "Type" },
    ArgusType = { link = "Type" },
    ArgusConst = { link = "Constant" },
    ArgusVar = { link = "Identifier" },
    ArgusField = { link = "Identifier" },

    -- UI elements
    ArgusIcon = { link = "Special" },
    ArgusLineNr = { link = "LineNr" },
    ArgusFoldIcon = { link = "Comment" },
    ArgusSelected = { link = "Visual" },
    ArgusFilter = { link = "Search" },

    -- Receiver in methods
    ArgusReceiver = { link = "Comment" },
    ArgusSignature = { link = "Comment" },
  }

  for name, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, name, opts)
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
