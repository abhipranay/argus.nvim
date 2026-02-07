.PHONY: test test-file lint help

TESTS_DIR = tests

# Run all tests
test:
	@nvim --headless -u $(TESTS_DIR)/minimal_init.lua \
		-c "PlenaryBustedDirectory $(TESTS_DIR)/ {minimal_init = '$(TESTS_DIR)/minimal_init.lua', sequential = true}"

# Run a specific test file
# Usage: make test-file FILE=tests/config_spec.lua
test-file:
	@nvim --headless -u $(TESTS_DIR)/minimal_init.lua \
		-c "PlenaryBustedFile $(FILE)"

# Lint with luacheck (if installed)
lint:
	@luacheck lua/ --no-unused-args --no-max-line-length

# Generate help tags
helptags:
	@nvim --headless -c "helptags doc/" -c "q"

help:
	@echo "Available targets:"
	@echo "  test        - Run all tests"
	@echo "  test-file   - Run specific test (FILE=tests/xxx_spec.lua)"
	@echo "  lint        - Run luacheck linter"
	@echo "  helptags    - Generate help tags"
