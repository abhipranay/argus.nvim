# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2024-02-07

### Added
- Initial release
- Hierarchical symbol outline for Go files
- Two view modes: flat (file order) and hierarchy (grouped by type)
- Symbol types: package, function, method, struct, interface, type, const, var, field
- Move symbols up/down with `K`/`J` keys
- Struct fields displayed as children
- Interface methods displayed as children
- Doc comments move with their associated symbols
- Live filtering with `/` key
- Cursor synchronization between source and outline
- Folding support with `za`, `zR`, `zM`
- Multiple icon presets: default, material, devicons, minimal
- Help popup with `?` key
- Full help documentation (`:help argus`)
- Commands: `:ArgusToggle`, `:ArgusOpen`, `:ArgusClose`, `:ArgusRefresh`

### Configuration Options
- `position`: Window position (left/right)
- `width`: Window width
- `auto_close`: Auto-close when source buffer closes
- `show_line_numbers`: Show line numbers in outline
- `auto_preview`: Preview on cursor move
- `follow_cursor`: Sync outline cursor with source
- `view_mode`: Initial view mode (flat/hierarchy)
- `icons`: Customizable icons
- `keymaps`: Customizable keybindings
