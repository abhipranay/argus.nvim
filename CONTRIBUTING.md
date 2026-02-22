# Contributing to argus.nvim

Thank you for your interest in contributing to argus.nvim! This document provides guidelines and information for contributors.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a new branch for your feature or bug fix

## Architecture Overview

argus.nvim is a Go code outline/navigator plugin for Neovim. It uses Treesitter to parse Go source files and displays an interactive outline in a side panel.

### Data Flow

```
Source Buffer (Go file)
    |
    v
parser.parse_buffer() --> symbols[]
    |
    v
render.render() --> outline display
    |
    v
User interacts (keymaps)
    |
    v
actions.* --> modify source
    |
    v
Re-parse and re-render
```

### Module Diagram

```
+------------------+
|     init.lua     |  Entry point, setup, commands
+--------+---------+
         |
         v
+--------+---------+     +------------------+
|   config.lua     |<----|  highlights.lua  |
+--------+---------+     +------------------+
         |
         v
+--------+---------+
|   parser.lua     |  Treesitter parsing, symbol extraction
+--------+---------+
         |
         v
+--------+---------+
|   symbols.lua    |  Symbol data structure, utilities
+--------+---------+
         |
    +----+----+
    |         |
    v         v
+---+----+ +--+-----+
|render  | |actions |  Display / User interactions
+---+----+ +--+-----+
    |         |
    v         v
+---+----+ +--+------+
|window  | |formatter|  Window mgmt / File formatting
+--------+ +---------+
               |
               v
         +-----+-----+
         |  filter   |  Live filtering
         +-----------+
```

## Module Descriptions

| Module | Purpose |
|--------|---------|
| `init.lua` | Entry point. Exposes `setup()`, creates commands (`:Argus`, `:ArgusToggle`, `:ArgusFormatFile`), manages plugin lifecycle |
| `parser.lua` | Treesitter-based Go parser. Extracts functions, methods, types, consts, vars from source buffer. Supports flat and hierarchy modes |
| `symbols.lua` | Symbol data structure and utilities. Provides `new()`, `flatten()`, `get_siblings()`, `get_group_siblings()` for navigation |
| `actions.lua` | User actions invoked from keymaps. Includes `jump_to_symbol()`, `move_up()`, `move_down()`, `toggle_fold()`, and group-aware move logic |
| `render.lua` | Renders symbols into outline buffer. Handles icons, indentation, collapsed state. Maps outline lines to symbols |
| `window.lua` | Window management. Opens/closes outline panel, tracks source/outline window IDs and buffer numbers |
| `config.lua` | Configuration management. Default keymaps, icons presets (default, ascii, nerdfont, mini), view modes |
| `formatter.lua` | File formatting (`:ArgusFormatFile`). Reorders declarations, sorts groups alphabetically. Group detection utilities |
| `filter.lua` | Live filtering in outline. Matches symbol names against user input |
| `highlights.lua` | Syntax highlighting groups for outline buffer |

## Key Data Structures

### Symbol

The core data structure representing a parsed Go symbol:

```lua
---@class Symbol
---@field name string           -- Symbol name (e.g., "NewFoo", "Start")
---@field kind string           -- "function"|"method"|"struct"|"interface"|"const"|"var"|"type"|"package"
---@field icon string           -- Display icon for the kind
---@field start_line number     -- 1-indexed, includes leading comments
---@field end_line number       -- 1-indexed, last line of symbol
---@field code_start_line number -- 1-indexed, actual declaration line (excludes comments)
---@field receiver string|nil   -- For methods: receiver type (e.g., "s *Server")
---@field children Symbol[]     -- Child symbols (methods under struct in hierarchy mode)
---@field parent Symbol|nil     -- Parent symbol reference
---@field collapsed boolean     -- Whether node is collapsed in outline
---@field signature string|nil  -- Function/method parameter signature for display
```

### Config

Plugin configuration (see `config.lua` for defaults):

```lua
{
  width = 40,                    -- Outline window width
  position = "right",            -- "left" or "right"
  auto_preview = false,          -- Preview symbol on cursor move
  auto_close = false,            -- Close outline when jumping
  view_mode = "flat",            -- "flat" or "hierarchy"
  show_signature = true,         -- Show function signatures
  keymaps = { ... },             -- Key bindings
  icons = "default",             -- Icon preset name or table
  format_template = { ... },     -- Section order for formatting
}
```

## Key Features

### Group-Aware Move

The move functionality (`K`/`J` keys) is aware of grouped declarations (`var ()`, `const ()`, `type ()`):

**Extracting from group (move at edge):**
- Moving the first item UP extracts it as a standalone declaration with keyword added
- Moving the last item DOWN extracts it as a standalone declaration
- Comments above the group are preserved with the group

**Inserting into group (move into group):**
- Moving a standalone symbol into a group strips the keyword and inserts it
- Indentation is matched to existing group items

**Singleton conversion:**
- When a 2-item group becomes 1 item, it's converted to standalone (`var (x)` → `var x`)

**Iota protection:**
- Const groups using `iota` cannot be reordered (would change values)

Key functions in `actions.lua`:
- `extract_from_group()` - Extracts symbol from group, handles singleton conversion
- `_insert_into_group()` - Inserts standalone into group, strips keyword
- `is_at_group_edge()` - Checks if symbol is first/last in group
- `convert_singleton_to_standalone()` - Converts `var (x)` to `var x`

Key functions in `formatter.lua`:
- `is_in_group()` - Uses treesitter to detect grouped declarations
- `find_group_boundaries()` - Finds `var (`...`)` range
- `get_group_keyword()` - Returns "const", "var", or "type"

## Adding Features

### Adding a New Action

1. Add the function to `lua/argus/actions.lua`
2. Add a keymap entry to `lua/argus/config.lua` defaults
3. Register the keymap in `lua/argus/render.lua` `setup_keymaps()`
4. Add to help popup in `actions.show_help()`

### Adding a New Symbol Kind

1. Update `lua/argus/parser.lua` to detect and extract the kind
2. Add icon to all presets in `lua/argus/config.lua`
3. Add highlight group in `lua/argus/highlights.lua`
4. Update tests in `tests/parser_spec.lua`

### Adding a New Icon Preset

1. Add the preset table to `icon_presets` in `lua/argus/config.lua`
2. Ensure all required keys are present (see `DEFAULT_ICONS`)

## Development Setup

### Prerequisites

- Neovim >= 0.9.0
- Go treesitter parser (`TSInstall go`)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) for running tests

### Local Development

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/argus.nvim.git
cd argus.nvim

# Add the plugin to your Neovim config for testing
# In your lazy.nvim config:
{ dir = "/path/to/argus.nvim" }
```

## Code Style

### General

- Lua 5.1 compatible (Neovim's embedded Lua)
- Use LuaDoc comments (`---@param`, `---@return`) for public functions
- Prefer descriptive variable names over single characters (except `i`, `j`, `k` for loops)
- Keep functions focused and small

### Naming Conventions

- Local functions: `snake_case`
- Module functions: `M.snake_case`
- Private helpers: `local function name()` (not exported)
- Constants: `UPPER_SNAKE_CASE`

### Line Handling

Neovim APIs use 0-indexed lines, but symbol data uses 1-indexed:

```lua
-- Symbol stores 1-indexed lines
symbol.start_line = 10  -- Line 10 in editor

-- Convert to 0-indexed for nvim_buf_* APIs
local start_0 = symbol.start_line - 1
vim.api.nvim_buf_get_lines(buf, start_0, start_0 + 1, false)
```

### Error Handling

- Use `pcall()` for operations that may fail
- Return early on invalid input
- Provide user feedback via `vim.notify()` for user-facing errors

```lua
local ok, result = pcall(potentially_failing_function)
if not ok then
  vim.notify("argus: Operation failed", vim.log.levels.WARN)
  return
end
```

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run a specific test file
make test-file FILE=tests/config_spec.lua
```

### Test Structure

- `tests/minimal_init.lua` - Minimal Neovim config for tests
- `tests/*_spec.lua` - Test files for each module

### Writing Tests

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)'s busted-style testing:

```lua
describe("module_name", function()
  describe("function_name", function()
    it("should do something", function()
      -- Arrange
      local input = ...

      -- Act
      local result = module.function_name(input)

      -- Assert
      assert.equals(expected, result)
    end)
  end)
end)
```

### Test Helpers

Common patterns used in tests:

```lua
-- Create a test buffer with Go code
local function create_go_buffer(content)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
  vim.bo[buf].filetype = "go"
  return buf
end

-- Get buffer content as string
local function get_buffer_content(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  return table.concat(lines, "\n")
end
```

## Submitting Changes

### Commit Messages

Follow conventional commit format:

```
type(scope): description

[optional body]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Adding or updating tests
- `refactor`: Code refactoring
- `chore`: Maintenance tasks

Examples:
```
feat(parser): add support for type aliases
fix(window): prevent crash when buffer is deleted
docs: update installation instructions
```

### Pull Request Process

1. Ensure your code passes all tests (`make test`)
2. Update documentation if needed
3. Add tests for new features
4. Create a Pull Request with a clear description
5. Link any related issues

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactoring

## Testing
- [ ] Tests pass locally
- [ ] Added new tests for changes

## Related Issues
Fixes #(issue number)
```

## Reporting Issues

### Bug Reports

Please include:
- Neovim version (`:version`)
- Plugin version/commit
- Steps to reproduce
- Expected vs actual behavior
- Minimal config to reproduce

### Feature Requests

Please include:
- Use case description
- Proposed solution (if any)
- Alternatives considered

## Questions?

Feel free to open an issue for questions or discussions about the project.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
