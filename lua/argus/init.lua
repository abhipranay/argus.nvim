-- argus.nvim - Go Code Outline Plugin
-- Main entry point and public API

local M = {}

local config = require("argus.config")
local window = require("argus.window")
local render = require("argus.render")
local parser = require("argus.parser")
local actions = require("argus.actions")
local filter = require("argus.filter")
local highlights = require("argus.highlights")

---Setup the plugin with user configuration
---@param opts ArgusConfig|nil
function M.setup(opts)
  config.setup(opts)
  highlights.setup()
  M._setup_commands()
  M._setup_autocmds()
end

---Open the outline window
---@param bufnr number|nil Source buffer (default: current)
function M.open(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not window.open(bufnr) then
    return
  end

  -- Parse and render
  local symbols = parser.parse_buffer(bufnr)
  local outline_buf = window.get_outline_bufnr()

  if outline_buf then
    render.render(outline_buf, symbols)
    M._setup_keymaps(outline_buf)
  end
end

---Close the outline window
function M.close()
  render.clear()
  window.close()
end

---Toggle the outline window
function M.toggle()
  if window.is_open() then
    M.close()
  else
    M.open()
  end
end

---Refresh the outline
function M.refresh()
  actions.refresh()
end

---Check if outline is open
---@return boolean
function M.is_open()
  return window.is_open()
end

---Setup keymaps for the outline buffer
---@param bufnr number
function M._setup_keymaps(bufnr)
  local cfg = config.get()
  local km = cfg.keymaps
  local opts = { buffer = bufnr, noremap = true, silent = true, nowait = true }

  -- Close
  vim.keymap.set("n", km.close, M.close, opts)

  -- Jump to symbol
  vim.keymap.set("n", km.jump, actions.jump_to_symbol, opts)

  -- Move up/down
  vim.keymap.set("n", km.move_up, actions.move_up, opts)
  vim.keymap.set("n", km.move_down, actions.move_down, opts)

  -- Fold operations
  vim.keymap.set("n", km.toggle_fold, actions.toggle_fold, opts)
  vim.keymap.set("n", km.expand_all, actions.expand_all, opts)
  vim.keymap.set("n", km.collapse_all, actions.collapse_all, opts)

  -- Filter
  vim.keymap.set("n", km.filter, filter.open_live_filter, opts)
  vim.keymap.set("n", km.clear_filter, filter.clear_filter, opts)

  -- Refresh
  vim.keymap.set("n", km.refresh, actions.refresh, opts)

  -- Toggle view mode
  vim.keymap.set("n", km.toggle_view, actions.toggle_view, opts)

  -- Help
  vim.keymap.set("n", km.help, actions.show_help, opts)

  -- Auto-preview on cursor move (if enabled)
  if cfg.auto_preview then
    vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = bufnr,
      callback = actions.preview_symbol,
    })
  end
end

---Setup user commands
function M._setup_commands()
  vim.api.nvim_create_user_command("ArgusOpen", function()
    M.open()
  end, { desc = "Open Argus outline window" })

  vim.api.nvim_create_user_command("ArgusClose", function()
    M.close()
  end, { desc = "Close Argus outline window" })

  vim.api.nvim_create_user_command("ArgusToggle", function()
    M.toggle()
  end, { desc = "Toggle Argus outline window" })

  vim.api.nvim_create_user_command("ArgusRefresh", function()
    M.refresh()
  end, { desc = "Refresh Argus outline" })

  vim.api.nvim_create_user_command("ArgusFormatFile", function()
    require("argus.formatter").format_buffer()
  end, { desc = "Format Go file according to template" })
end

---Setup autocmds for plugin events
function M._setup_autocmds()
  local group = vim.api.nvim_create_augroup("ArgusPlugin", { clear = true })

  -- Handle refresh events
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "ArgusRefresh",
    callback = function()
      if M.is_open() then
        M.refresh()
      end
    end,
  })

  -- Handle cursor sync events
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "ArgusSyncCursor",
    callback = function()
      if M.is_open() then
        actions.sync_cursor_from_source()
      end
    end,
  })

  -- Refresh outline when switching to a different buffer
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(ev)
      if not M.is_open() then
        return
      end

      local bufnr = ev.buf
      local outline_buf = window.get_outline_bufnr()

      -- Don't refresh if entering the outline buffer itself
      if bufnr == outline_buf then
        return
      end

      -- Only refresh for Go files
      local ft = vim.bo[bufnr].filetype
      if ft ~= "go" then
        return
      end

      -- Update source buffer reference and refresh
      window.set_source_buffer(bufnr)
      local symbols = parser.parse_buffer(bufnr)
      render.render(outline_buf, symbols)
    end,
  })
end

-- Export submodules for advanced usage
M.window = window
M.render = render
M.parser = parser
M.actions = actions
M.filter = filter
M.config = config
M.formatter = require("argus.formatter")

return M
