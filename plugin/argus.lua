-- argus.nvim plugin loader
-- Automatically loaded by Neovim

-- Prevent loading twice
if vim.g.loaded_argus then
  return
end
vim.g.loaded_argus = true

-- Check Neovim version
if vim.fn.has("nvim-0.9.0") ~= 1 then
  vim.notify("argus.nvim requires Neovim >= 0.9.0", vim.log.levels.ERROR)
  return
end

-- Lazy-load the plugin on first use
local function ensure_setup()
  local argus = require("argus")
  -- Setup with defaults if not already setup
  if vim.tbl_isempty(require("argus.config").options) then
    argus.setup()
  end
  return argus
end

-- Create commands that lazy-load the plugin
vim.api.nvim_create_user_command("ArgusOpen", function()
  ensure_setup().open()
end, { desc = "Open Argus outline window" })

vim.api.nvim_create_user_command("ArgusClose", function()
  ensure_setup().close()
end, { desc = "Close Argus outline window" })

vim.api.nvim_create_user_command("ArgusToggle", function()
  ensure_setup().toggle()
end, { desc = "Toggle Argus outline window" })

vim.api.nvim_create_user_command("ArgusRefresh", function()
  ensure_setup().refresh()
end, { desc = "Refresh Argus outline" })
