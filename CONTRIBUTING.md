# Contributing to argus.nvim

Thank you for your interest in contributing to argus.nvim! This document provides guidelines and information for contributors.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a new branch for your feature or bug fix

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

- Follow existing code patterns and style
- Use meaningful variable and function names
- Add type annotations using LuaCATS/EmmyLua format
- Keep functions focused and reasonably sized

### Lua Style Guidelines

```lua
-- Use local for all module-level functions
local function my_function()
end

-- Export public functions via module table
function M.public_function()
end

-- Add type annotations
---@param bufnr number Buffer number
---@return Symbol[]
function M.parse_buffer(bufnr)
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

### Writing Tests

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)'s busted-style testing:

```lua
describe("module_name", function()
  it("should do something", function()
    local result = module.function()
    assert.equals(expected, result)
  end)
end)
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
