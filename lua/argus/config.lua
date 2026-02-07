-- argus.nvim configuration module
local M = {}

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
  -- VS Code / Codicons style - clean and recognizable
  codicons = {
    package = "",
    ["function"] = "",
    method = "",
    struct = "",
    interface = "",
    type = "",
    const = "",
    var = "",
    field = "",
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
  -- Minimal/Simple style
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
  -- Outline style (similar to symbols-outline.nvim)
  outline = {
    package = "",
    ["function"] = "",
    method = "",
    struct = "",
    interface = "",
    type = "",
    const = "",
    var = "",
    field = "",
    collapsed = "",
    expanded = "",
  },
}

---@type ArgusConfig
M.defaults = {
  -- Window
  position = "right",
  width = 40,
  auto_close = true,

  -- Display (using codicons preset by default)
  icons = M.icon_presets.codicons,
  show_line_numbers = true,

  -- Behavior
  auto_preview = false,
  follow_cursor = true,
  view_mode = "flat", -- "flat" (file order) or "hierarchy" (grouped by type)

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
end

---Get current configuration
---@return ArgusConfig
function M.get()
  if vim.tbl_isempty(M.options) then
    M.setup()
  end
  return M.options
end

---Get icon for a symbol kind
---@param kind string
---@return string
function M.get_icon(kind)
  local config = M.get()
  return config.icons[kind] or ""
end

---Get an icon preset by name
---@param name string Preset name: "codicons", "material", "minimal", "outline"
---@return table
function M.get_preset(name)
  return M.icon_presets[name] or M.icon_presets.codicons
end

return M
