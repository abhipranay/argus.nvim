# argus.nvim

A Neovim plugin that displays a hierarchical outline of Go source code symbols with the ability to reorder symbols by moving them up/down in the outline window.

## Features

- **Hierarchical Symbol Outline**: View structs, interfaces, functions, methods, constants, and variables in a tree structure
- **Method Grouping**: Methods are automatically nested under their receiver types
- **Symbol Reordering**: Move symbols up/down in the source code directly from the outline
- **Comment Preservation**: Doc comments move with their associated symbols
- **Live Filtering**: Search/filter symbols interactively
- **Cursor Sync**: Outline cursor follows your position in the source file
- **Folding**: Collapse/expand symbol groups

## Requirements

- Neovim >= 0.9.0
- nvim-treesitter with Go parser installed

## Installation

### lazy.nvim

```lua
{
  "yourusername/argus.nvim",
  ft = "go",
  opts = {},
  keys = {
    { "<leader>cs", "<cmd>ArgusToggle<cr>", desc = "Toggle Code Outline" },
  },
}
```

### packer.nvim

```lua
use {
  "yourusername/argus.nvim",
  config = function()
    require("argus").setup()
  end,
  ft = "go",
}
```

## Configuration

```lua
require("argus").setup({
  -- Window
  position = "right",      -- "left" | "right"
  width = 40,              -- window width
  auto_close = true,       -- close when source buffer closes

  -- Display
  icons = {
    package = "󰏗",
    ["function"] = "󰊕",
    method = "󰆧",
    struct = "󰙅",
    interface = "󰜰",
    type = "󰊄",
    const = "󰏿",
    var = "󰀫",
    collapsed = "",
    expanded = "",
  },
  show_line_numbers = true,

  -- Behavior
  auto_preview = false,    -- preview symbol on cursor move
  follow_cursor = true,    -- sync outline cursor with source

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
  },
})
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:ArgusToggle` | Toggle the outline window |
| `:ArgusOpen` | Open the outline window |
| `:ArgusClose` | Close the outline window |
| `:ArgusRefresh` | Refresh the outline |

### Keymaps (in outline window)

| Key | Action |
|-----|--------|
| `q` | Close outline |
| `<CR>` | Jump to symbol in source |
| `K` | Move symbol up in source code |
| `J` | Move symbol down in source code |
| `za` | Toggle fold |
| `zR` | Expand all |
| `zM` | Collapse all |
| `/` | Open filter prompt |
| `<Esc>` | Clear filter |
| `R` | Refresh outline |

### Suggested Global Keymap

```lua
vim.keymap.set("n", "<leader>cs", "<cmd>ArgusToggle<cr>", { desc = "Toggle Code Outline" })
```

## Outline Display

Symbols are displayed hierarchically with methods grouped under their receiver types:

```
󰏗 main
󰙅 Config
   󰆧 NewConfig() *Config
   󰆧 (c *Config) Validate() error
   󰆧 (c *Config) Save() error
󰙅 Server
   󰆧 NewServer(cfg *Config) *Server
   󰆧 (s *Server) Start() error
   󰆧 (s *Server) Stop() error
󰜰 Handler
󰊕 main()
󰊕 init()
󰏿 DefaultTimeout
󰏿 MaxConnections
󰀫 logger
```

## Symbol Types

| Symbol | Icon | Description |
|--------|------|-------------|
| Package | 󰏗 | Package declaration |
| Function | 󰊕 | Function declaration |
| Method | 󰆧 | Method declaration |
| Struct | 󰙅 | Struct type |
| Interface | 󰜰 | Interface type |
| Type | 󰊄 | Type alias |
| Const | 󰏿 | Constant |
| Var | 󰀫 | Variable |

## How Symbol Moving Works

When you press `K` or `J` to move a symbol:

1. The plugin identifies the symbol at the cursor position
2. Finds the adjacent sibling symbol (previous for up, next for down)
3. Extracts the source lines including any preceding comments
4. Swaps the positions of the two symbols in the source file
5. Re-parses and re-renders the outline
6. Positions the cursor on the moved symbol

This allows you to quickly reorganize your Go code without manual cut/paste operations.

## License

MIT
