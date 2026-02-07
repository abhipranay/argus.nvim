-- Minimal init for running tests
-- Usage: nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if not vim.loop.fs_stat(plenary_path) then
  print("Plenary not found, cloning...")
  vim.fn.system({
    "git",
    "clone",
    "--depth=1",
    "https://github.com/nvim-lua/plenary.nvim",
    plenary_path,
  })
end
vim.opt.runtimepath:prepend(plenary_path)

-- Add plugin to runtimepath
local plugin_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.runtimepath:prepend(plugin_path)

-- Set up treesitter for Go
vim.cmd([[runtime plugin/argus.lua]])
