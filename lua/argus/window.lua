-- argus.nvim window management module
local M = {}

local config = require("argus.config")

-- State
local state = {
  outline_win = nil,
  outline_buf = nil,
  source_win = nil,
  source_buf = nil,
}

---Check if outline window is open
---@return boolean
function M.is_open()
  return state.outline_win ~= nil
    and vim.api.nvim_win_is_valid(state.outline_win)
    and state.outline_buf ~= nil
    and vim.api.nvim_buf_is_valid(state.outline_buf)
end

---Get the outline buffer number
---@return number|nil
function M.get_outline_bufnr()
  if state.outline_buf and vim.api.nvim_buf_is_valid(state.outline_buf) then
    return state.outline_buf
  end
  return nil
end

---Get the outline window number
---@return number|nil
function M.get_outline_win()
  if state.outline_win and vim.api.nvim_win_is_valid(state.outline_win) then
    return state.outline_win
  end
  return nil
end

---Get the source buffer number
---@return number|nil
function M.get_source_bufnr()
  if state.source_buf and vim.api.nvim_buf_is_valid(state.source_buf) then
    return state.source_buf
  end
  return nil
end

---Get the source window number
---@return number|nil
function M.get_source_win()
  if state.source_win and vim.api.nvim_win_is_valid(state.source_win) then
    return state.source_win
  end
  return nil
end

---Create the outline buffer
---@return number Buffer number
local function create_outline_buffer()
  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "argus"
  vim.bo[buf].modifiable = false

  vim.api.nvim_buf_set_name(buf, "Argus Outline")

  return buf
end

---Open the outline window
---@param source_bufnr number|nil Source buffer to show outline for
---@return boolean Success
function M.open(source_bufnr)
  if M.is_open() then
    -- Already open, just focus
    vim.api.nvim_set_current_win(state.outline_win)
    return true
  end

  local cfg = config.get()

  -- Store source window and buffer
  state.source_win = vim.api.nvim_get_current_win()
  state.source_buf = source_bufnr or vim.api.nvim_get_current_buf()

  -- Check if source is a Go file
  if vim.bo[state.source_buf].filetype ~= "go" then
    vim.notify("argus: Not a Go file", vim.log.levels.WARN)
    return false
  end

  -- Create outline buffer
  state.outline_buf = create_outline_buffer()

  -- Create window
  local split_cmd
  if cfg.position == "left" then
    split_cmd = "topleft vsplit"
  else
    split_cmd = "botright vsplit"
  end

  vim.cmd(split_cmd)
  state.outline_win = vim.api.nvim_get_current_win()

  -- Set buffer in window
  vim.api.nvim_win_set_buf(state.outline_win, state.outline_buf)

  -- Configure window
  vim.api.nvim_win_set_width(state.outline_win, cfg.width)
  vim.wo[state.outline_win].number = false
  vim.wo[state.outline_win].relativenumber = false
  vim.wo[state.outline_win].signcolumn = "no"
  vim.wo[state.outline_win].foldcolumn = "0"
  vim.wo[state.outline_win].wrap = false
  vim.wo[state.outline_win].spell = false
  vim.wo[state.outline_win].list = false
  vim.wo[state.outline_win].cursorline = true
  vim.wo[state.outline_win].winfixwidth = true

  -- Setup autocommands for this window
  M.setup_autocmds()

  return true
end

---Close the outline window
function M.close()
  if state.outline_win and vim.api.nvim_win_is_valid(state.outline_win) then
    vim.api.nvim_win_close(state.outline_win, true)
  end

  state.outline_win = nil
  state.outline_buf = nil
end

---Toggle the outline window
---@param source_bufnr number|nil
function M.toggle(source_bufnr)
  if M.is_open() then
    M.close()
  else
    M.open(source_bufnr)
  end
end

---Focus the source window
function M.focus_source()
  if state.source_win and vim.api.nvim_win_is_valid(state.source_win) then
    vim.api.nvim_set_current_win(state.source_win)
  end
end

---Focus the outline window
function M.focus_outline()
  if state.outline_win and vim.api.nvim_win_is_valid(state.outline_win) then
    vim.api.nvim_set_current_win(state.outline_win)
  end
end

---Setup autocmds for outline window behavior
function M.setup_autocmds()
  local cfg = config.get()
  local group = vim.api.nvim_create_augroup("ArgusOutline", { clear = true })

  -- Close outline when source buffer is closed
  if cfg.auto_close then
    vim.api.nvim_create_autocmd("BufDelete", {
      group = group,
      buffer = state.source_buf,
      callback = function()
        M.close()
      end,
    })
  end

  -- Update outline when source changes
  vim.api.nvim_create_autocmd({ "BufWritePost", "TextChanged", "InsertLeave" }, {
    group = group,
    buffer = state.source_buf,
    callback = function()
      if M.is_open() then
        -- Trigger refresh (will be handled by init.lua)
        vim.api.nvim_exec_autocmds("User", { pattern = "ArgusRefresh" })
      end
    end,
  })

  -- Sync cursor from source to outline
  if cfg.follow_cursor then
    vim.api.nvim_create_autocmd("CursorMoved", {
      group = group,
      buffer = state.source_buf,
      callback = function()
        if M.is_open() then
          vim.api.nvim_exec_autocmds("User", { pattern = "ArgusSyncCursor" })
        end
      end,
    })
  end

  -- Handle outline window close
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      if tonumber(ev.match) == state.outline_win then
        state.outline_win = nil
        state.outline_buf = nil
      end
    end,
  })
end

---Update the source buffer and window reference (for when switching files)
---@param bufnr number
function M.set_source_buffer(bufnr)
  state.source_buf = bufnr
  -- Also update source window to current window (if not the outline window)
  local current_win = vim.api.nvim_get_current_win()
  if current_win ~= state.outline_win then
    state.source_win = current_win
  end
end

---Get current state (for debugging)
---@return table
function M.get_state()
  return vim.deepcopy(state)
end

return M
