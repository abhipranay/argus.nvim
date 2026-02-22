-- argus.nvim configuration module
local M = {}

-- Map argus symbol kinds to LSP SymbolKind names (for mini.icons)
M.lsp_kind_map = {
  package = "Module",
  ["function"] = "Function",
  method = "Method",
  struct = "Struct",
  interface = "Interface",
  type = "TypeParameter",
  const = "Constant",
  var = "Variable",
  field = "Field",
}

-- Sentinel value to indicate mini.icons should be used
M.MINI_ICONS = "mini"

---@class ArgusConfig
---@field position string Window position ("left" | "right")
---@field width number Window width
---@field auto_close boolean Close when source buffer closes
---@field icons table<string, string> Icons for each symbol type
---@field show_line_numbers boolean Show line numbers in outline
---@field auto_preview boolean Preview symbol on cursor move
---@field follow_cursor boolean Sync outline cursor with source
---@field keymaps table<string, string> Keymap bindings

-- Icon presets (all require Nerd Fonts)
M.icon_presets = {
  -- Default style - clear and recognizable
  default = {
    package = "󰏗",
    ["function"] = "󰊕",
    method = "󰆧",
    struct = "󰙅",
    interface = "󰜰",
    type = "󰊄",
    const = "󰏿",
    var = "󰀫",
    field = "󰜢",
    collapsed = "",
    expanded = "",
  },
  -- Material Design style
  material = {
    package = "󰏗",
    ["function"] = "󰡱",
    method = "󰆧",
    struct = "󰆼",
    interface = "󰜰",
    type = "󰊄",
    const = "󰏿",
    var = "󰀫",
    field = "󰆨",
    collapsed = "󰁕",
    expanded = "󰁆",
  },
  -- Minimal/Simple style (no special font needed)
  minimal = {
    package = "P",
    ["function"] = "ƒ",
    method = "m",
    struct = "S",
    interface = "I",
    type = "T",
    const = "C",
    var = "v",
    field = "·",
    collapsed = "▸",
    expanded = "▾",
  },
  -- Codicons style (VS Code icons from Nerd Fonts)
  codicons = {
    package = "\u{eb29}",
    ["function"] = "\u{eb93}",
    method = "\u{eb92}",
    struct = "\u{eb5b}",
    interface = "\u{eb61}",
    type = "\u{eb5b}",
    const = "\u{eb5d}",
    var = "\u{ea88}",
    field = "\u{eb5f}",
    collapsed = "\u{eab6}",
    expanded = "\u{eab4}",
  },
}

---@type ArgusConfig
M.defaults = {
  -- Window
  position = "right",
  width = 40,
  auto_close = true,

  -- Display
  -- icons can be: a preset table, a preset name ("default", "material", "minimal", "devicons", "mini")
  -- Use "mini" to use mini.icons (requires mini.icons plugin)
  icons = M.icon_presets.default,
  show_line_numbers = true,

  -- Behavior
  auto_preview = false,
  follow_cursor = true,
  view_mode = "flat", -- "flat" (file order) or "hierarchy" (grouped by type)

  -- Format template for :ArgusFormatFile
  format_template = {
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
  },

  -- Keymaps (in outline window)
  keymaps = {
    close = "q",
    jump = "<CR>",
    move_up = "K",
    move_down = "J",
    toggle_fold = "za",
    expand_all = "zR",
    collapse_all = "zM",
    filter = "/",
    clear_filter = "<Esc>",
    refresh = "R",
    toggle_view = "v",
    help = "?",
  },
}

---@type ArgusConfig
M.options = {}

---Setup configuration with user options
---@param opts ArgusConfig|nil
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})

  -- Handle icons as string (preset name)
  if type(M.options.icons) == "string" then
    local preset_name = M.options.icons
    if preset_name == "mini" then
      -- Keep as "mini" string - will be handled specially
      M.options.icons = M.MINI_ICONS
    else
      -- Look up preset by name
      M.options.icons = M.icon_presets[preset_name] or M.icon_presets.default
    end
  end
end

---Get current configuration
---@return ArgusConfig
function M.get()
  if vim.tbl_isempty(M.options) then
    M.setup()
  end
  return M.options
end

---Check if mini.icons is available
---@return boolean
function M.is_mini_icons_available()
  local ok, _ = pcall(require, "mini.icons")
  return ok
end

---Check if config is set to use mini.icons
---@return boolean
function M.uses_mini_icons()
  local cfg = M.get()
  return cfg.icons == M.MINI_ICONS
end

---Get icon from mini.icons for a symbol kind
---@param kind string Symbol kind (function, method, struct, etc.)
---@return string|nil icon, string|nil highlight
function M.get_mini_icon(kind)
  if not M.is_mini_icons_available() then
    return nil, nil
  end

  local MiniIcons = require("mini.icons")

  -- Map argus kind to LSP kind
  local lsp_kind = M.lsp_kind_map[kind]
  if not lsp_kind then
    -- For collapsed/expanded, return nil (use fallback)
    return nil, nil
  end

  -- Get icon from mini.icons
  local ok, icon, hl = pcall(MiniIcons.get, "lsp", lsp_kind)
  if ok and icon then
    return icon, hl
  end

  return nil, nil
end

---Get icon for a symbol kind
---@param kind string
---@return string
function M.get_icon(kind)
  local cfg = M.get()

  if cfg.icons == M.MINI_ICONS then
    local icon, _ = M.get_mini_icon(kind)
    if icon then
      return icon
    end
    -- Fall back to default preset for collapsed/expanded or if mini.icons unavailable
    return M.icon_presets.default[kind] or ""
  end

  return cfg.icons[kind] or ""
end

---Get icon for a symbol kind with highlight group
---@param kind string
---@return string icon, string|nil highlight
function M.get_icon_with_hl(kind)
  local cfg = M.get()

  if cfg.icons == M.MINI_ICONS then
    local icon, hl = M.get_mini_icon(kind)
    if icon then
      return icon, hl
    end
    -- Fall back to default preset for collapsed/expanded or if mini.icons unavailable
    return M.icon_presets.default[kind] or "", nil
  end

  return cfg.icons[kind] or "", nil
end

---Get an icon preset by name
---@param name string Preset name: "default", "material", "minimal", "devicons", "mini"
---@return table|string
function M.get_preset(name)
  if name == "mini" then
    return M.MINI_ICONS
  end
  return M.icon_presets[name] or M.icon_presets.default
end

return M
