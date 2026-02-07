-- argus.nvim filter module
local M = {}

local window = require("argus.window")
local render = require("argus.render")

-- State
local filter_state = {
  active = false,
  pattern = "",
  cached_symbols = nil,
}

---Check if filter is active
---@return boolean
function M.is_active()
  return filter_state.active
end

---Get current filter pattern
---@return string
function M.get_pattern()
  return filter_state.pattern
end

---Apply filter pattern and re-render
---@param pattern string
function M.apply_filter(pattern)
  filter_state.pattern = pattern
  filter_state.active = pattern ~= ""

  local outline_buf = window.get_outline_bufnr()
  if not outline_buf then
    return
  end

  -- Re-render with filter
  render.render(outline_buf, render.get_symbols(), pattern)
end

---Clear the filter
function M.clear_filter()
  filter_state.pattern = ""
  filter_state.active = false

  local outline_buf = window.get_outline_bufnr()
  if not outline_buf then
    return
  end

  render.render(outline_buf, render.get_symbols(), nil)
end

---Open filter prompt
function M.open_filter()
  local outline_win = window.get_outline_win()
  if not outline_win then
    return
  end

  -- Use vim.ui.input for the filter prompt
  vim.ui.input({
    prompt = "Filter: ",
    default = filter_state.pattern,
  }, function(input)
    if input == nil then
      -- User cancelled
      return
    end
    M.apply_filter(input)
  end)
end

---Interactive filter with live updates
function M.open_live_filter()
  local outline_win = window.get_outline_win()
  local outline_buf = window.get_outline_bufnr()
  if not outline_win or not outline_buf then
    return
  end

  -- Store original symbols for filtering
  filter_state.cached_symbols = render.get_symbols()

  -- Create a minimal cmdline-style input
  local input_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[input_buf].buftype = "nofile"

  -- Create floating window for input
  local width = 30
  local win_config = {
    relative = "win",
    win = outline_win,
    width = width,
    height = 1,
    row = 0,
    col = 0,
    style = "minimal",
    border = "single",
    title = " Filter ",
    title_pos = "center",
  }

  local input_win = vim.api.nvim_open_win(input_buf, true, win_config)
  vim.wo[input_win].cursorline = false

  -- Set initial content
  vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { filter_state.pattern })
  vim.bo[input_buf].modifiable = true

  -- Position cursor at end
  local col = #filter_state.pattern
  vim.api.nvim_win_set_cursor(input_win, { 1, col })

  -- Start insert mode
  vim.cmd("startinsert!")

  -- Setup keymaps for the input buffer
  local opts = { buffer = input_buf, noremap = true, silent = true }

  -- Enter to confirm
  vim.keymap.set({ "i", "n" }, "<CR>", function()
    local lines = vim.api.nvim_buf_get_lines(input_buf, 0, 1, false)
    local pattern = lines[1] or ""
    vim.api.nvim_win_close(input_win, true)
    M.apply_filter(pattern)
    window.focus_outline()
  end, opts)

  -- Escape to cancel
  vim.keymap.set({ "i", "n" }, "<Esc>", function()
    vim.api.nvim_win_close(input_win, true)
    -- Restore unfiltered view if cancelled
    if filter_state.cached_symbols then
      render.render(outline_buf, filter_state.cached_symbols, filter_state.pattern)
    end
    window.focus_outline()
  end, opts)

  -- Live update as user types
  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buffer = input_buf,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(input_buf, 0, 1, false)
      local pattern = lines[1] or ""
      if filter_state.cached_symbols then
        render.render(outline_buf, filter_state.cached_symbols, pattern)
      end
    end,
  })

  -- Clean up on window close
  vim.api.nvim_create_autocmd("WinClosed", {
    buffer = input_buf,
    once = true,
    callback = function()
      filter_state.cached_symbols = nil
    end,
  })
end

return M
