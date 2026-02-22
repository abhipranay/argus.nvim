# argus.nvim

[![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-green.svg?logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1-blue.svg?logo=lua)](https://www.lua.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Neovim plugin that displays a hierarchical outline of Go source code symbols with the ability to reorder symbols by moving them up/down in the outline window.

## ✨ Features

- **Hierarchical Symbol Outline**: View structs, interfaces, functions, methods, constants, and variables in a tree structure
- **Two View Modes**: Switch between flat (file order) and hierarchy (grouped) views
- **Symbol Reordering**: Move symbols up/down in the source code directly from the outline
- **File Formatting**: Reorganize Go files according to a customizable template (`:ArgusFormatFile`)
- **Method Grouping**: Methods automatically nested under their receiver types (in hierarchy view)
- **Struct Fields**: View struct fields and interface methods as children
- **Comment Preservation**: Doc comments move with their associated symbols
- **Live Filtering**: Search/filter symbols interactively
- **Cursor Sync**: Outline cursor follows your position in the source file
- **Folding**: Collapse/expand symbol groups
- **Multiple Icon Presets**: Choose from default, material, codicons, minimal, or mini.icons
- **Colorscheme Compatible**: Uses treesitter highlight groups for seamless theme integration

## 📋 Requirements

- Neovim >= 0.9.0
- nvim-treesitter with Go parser installed (`TSInstall go`)
- A [Nerd Font](https://www.nerdfonts.com/) (for icons, unless using `minimal` preset)

## 📦 Installation

### lazy.nvim

```lua
{
  "abhipranay/argus.nvim",
  ft = "go",
  opts = {},
  keys = {
    { "<leader>cs", "<cmd>ArgusToggle<cr>", desc = "Toggle Code Outline" },
    { "<leader>cf", "<cmd>ArgusFormatFile<cr>", desc = "Format Go File" },
  },
}
```

### lazy.nvim with mini.icons

```lua
{
  "abhipranay/argus.nvim",
  ft = "go",
  dependencies = { "echasnovski/mini.icons" },
  opts = {
    icons = "mini",
  },
  keys = {
    { "<leader>cs", "<cmd>ArgusToggle<cr>", desc = "Toggle Code Outline" },
    { "<leader>cf", "<cmd>ArgusFormatFile<cr>", desc = "Format Go File" },
  },
}
```

### packer.nvim

```lua
use {
  "abhipranay/argus.nvim",
  config = function()
    require("argus").setup()
  end,
  ft = "go",
}
```

## ⚙️ Configuration

```lua
require("argus").setup({
  -- Window
  position = "right",      -- "left" | "right"
  width = 40,              -- window width
  auto_close = true,       -- close when source buffer closes

  -- Display
  icons = "default",       -- "default" | "material" | "codicons" | "minimal" | "mini"
  show_line_numbers = true,

  -- Behavior
  auto_preview = false,    -- preview symbol on cursor move
  follow_cursor = true,    -- sync outline cursor with source
  view_mode = "flat",      -- "flat" (file order) | "hierarchy" (grouped)

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
})
```

### Icon Presets

| Preset | Description |
|--------|-------------|
| `default` | Clean Nerd Font icons (recommended) |
| `material` | Material Design style |
| `codicons` | VS Code style icons |
| `minimal` | ASCII-compatible (no special font needed) |
| `mini` | Use [mini.icons](https://github.com/echasnovski/mini.icons) (requires plugin) |

```lua
-- Use a different preset
require("argus").setup({
  icons = "material",
})

-- Or use mini.icons for automatic icon/highlight management
require("argus").setup({
  icons = "mini",
})
```

## 🚀 Usage

### Commands

| Command | Description |
|---------|-------------|
| `:ArgusToggle` | Toggle the outline window |
| `:ArgusOpen` | Open the outline window |
| `:ArgusClose` | Close the outline window |
| `:ArgusRefresh` | Refresh the outline |
| `:ArgusFormatFile` | Format Go file according to template |

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
| `v` | Toggle view mode (flat/hierarchy) |
| `?` | Show help |

## 📐 File Formatting

The `:ArgusFormatFile` command reorganizes your Go file according to the `format_template` configuration.

### How it works

- **Package and imports** always stay at the top (cannot be reordered)
- **Grouped declarations** (`const (...)`, `var (...)`, `type (...)`) stay together with items sorted alphabetically inside
- **Standalone structs** keep their methods attached: constructor → public methods → private methods (all sorted alphabetically)
- **Types in groups** have their methods placed in separate `public_methods`/`private_methods` sections
- **Comments** stay with their associated symbols

### Example

**Before:**
```go
package main

import "fmt"

func privateFunc() {}

type Foo struct{}

const (
    C = 3
    A = 1
)

func (f *Foo) PublicMethod() {}
func NewFoo() *Foo { return &Foo{} }
func (f *Foo) privateMethod() {}
func PublicFunc() {}
var x = 1
```

**After `:ArgusFormatFile`:**
```go
package main

import "fmt"

const (
    A = 1
    C = 3
)

var x = 1

type Foo struct{}

func NewFoo() *Foo { return &Foo{} }

func (f *Foo) PublicMethod() {}

func (f *Foo) privateMethod() {}

func PublicFunc() {}

func privateFunc() {}
```

## 📖 Outline Display

### Flat View (File Order)
Shows symbols in their actual order in the source file - useful for reorganizing code:

```
pkg  main
fn   NewConfig()
st   Config
     ├─ Host string
     └─ Port int
fn   helper()
mth  (c *Config) Validate()
mth  (c *Config) Save()
cst  MaxRetries
```

### Hierarchy View (Grouped)
Groups methods under their receiver types:

```
pkg  main
st   Config
     ├─ Host string
     ├─ Port int
     ├─ mth (c *Config) Validate()
     └─ mth (c *Config) Save()
fn   NewConfig()
fn   helper()
cst  MaxRetries
```

## 📝 Symbol Types

| Type | Abbreviation | Description |
|------|--------------|-------------|
| Package | `pkg` | Package declaration |
| Function | `fn` | Function declaration |
| Method | `mth` | Method declaration |
| Struct | `st` | Struct type |
| Interface | `if` | Interface type |
| Type | `typ` | Type alias |
| Const | `cst` | Constant |
| Var | `var` | Variable |
| Field | `fld` | Struct field |

## 🎨 Colorscheme Compatibility

argus.nvim automatically uses treesitter highlight groups (`@function`, `@type`, etc.) when available, falling back to classic Vim highlight groups for older colorschemes. This ensures the outline looks consistent with your theme.

When using `icons = "mini"`, icon colors are managed by mini.icons highlight groups.

You can override any highlight group:

```lua
-- After colorscheme is loaded
vim.api.nvim_set_hl(0, "ArgusFunction", { link = "Function" })
vim.api.nvim_set_hl(0, "ArgusStruct", { link = "Type" })
```

## 🔄 How Symbol Moving Works

When you press `K` or `J` to move a symbol:

1. The plugin identifies the symbol at the cursor position
2. Finds the adjacent sibling symbol (previous for up, next for down)
3. Extracts the source lines including any preceding comments
4. Swaps the positions of the two symbols in the source file
5. Re-parses and re-renders the outline
6. Positions the cursor on the moved symbol

This allows you to quickly reorganize your Go code without manual cut/paste operations.

## 🧪 Running Tests

```bash
make test
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) for the parsing infrastructure
- [mini.icons](https://github.com/echasnovski/mini.icons) for icon integration
- Inspired by [symbols-outline.nvim](https://github.com/simrat39/symbols-outline.nvim) and [aerial.nvim](https://github.com/stevearc/aerial.nvim)
