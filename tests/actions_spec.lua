local formatter = require("argus.formatter")
local symbols = require("argus.symbols")

-- Helper to create a buffer with Go code
local function create_go_buffer(content)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
  vim.bo[buf].filetype = "go"
  return buf
end

-- Helper to get buffer content as string
local function get_buffer_content(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  return table.concat(lines, "\n")
end

describe("formatter group functions", function()
  describe("is_in_group", function()
    it("should return true for symbol in var group", function()
      local buf = create_go_buffer([[
package main

var (
    a = 1
    b = 2
)
]])
      local symbol = symbols.new({
        name = "a",
        kind = "var",
        start_line = 4,
        end_line = 4,
        code_start_line = 4,
      })

      assert.is_true(formatter.is_in_group(buf, symbol))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return true for symbol in const group", function()
      local buf = create_go_buffer([[
package main

const (
    A = 1
    B = 2
)
]])
      local symbol = symbols.new({
        name = "A",
        kind = "const",
        start_line = 4,
        end_line = 4,
        code_start_line = 4,
      })

      assert.is_true(formatter.is_in_group(buf, symbol))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return true for symbol in type group", function()
      local buf = create_go_buffer([[
package main

type (
    Foo struct{}
    Bar struct{}
)
]])
      local symbol = symbols.new({
        name = "Foo",
        kind = "struct",
        start_line = 4,
        end_line = 4,
        code_start_line = 4,
      })

      assert.is_true(formatter.is_in_group(buf, symbol))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return false for standalone var", function()
      local buf = create_go_buffer([[
package main

var a = 1
var b = 2
]])
      local symbol = symbols.new({
        name = "a",
        kind = "var",
        start_line = 3,
        end_line = 3,
        code_start_line = 3,
      })

      assert.is_false(formatter.is_in_group(buf, symbol))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return false for function", function()
      local buf = create_go_buffer([[
package main

func foo() {}
]])
      local symbol = symbols.new({
        name = "foo",
        kind = "function",
        start_line = 3,
        end_line = 3,
        code_start_line = 3,
      })

      assert.is_false(formatter.is_in_group(buf, symbol))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("find_group_boundaries", function()
    it("should find boundaries for var group", function()
      local buf = create_go_buffer([[
package main

var (
    a = 1
    b = 2
)
]])
      local symbol = symbols.new({
        name = "a",
        kind = "var",
        start_line = 4,
        end_line = 4,
        code_start_line = 4,
      })

      local start_line, end_line = formatter.find_group_boundaries(buf, symbol)
      assert.equals(2, start_line) -- 0-indexed, "var ("
      assert.equals(5, end_line) -- 0-indexed, ")"

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should find boundaries for const group", function()
      local buf = create_go_buffer([[
package main

const (
    A = 1
    B = 2
    C = 3
)
]])
      local symbol = symbols.new({
        name = "B",
        kind = "const",
        start_line = 5,
        end_line = 5,
        code_start_line = 5,
      })

      local start_line, end_line = formatter.find_group_boundaries(buf, symbol)
      assert.equals(2, start_line) -- 0-indexed
      assert.equals(6, end_line) -- 0-indexed

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return nil for standalone symbol", function()
      local buf = create_go_buffer([[
package main

var a = 1
]])
      local symbol = symbols.new({
        name = "a",
        kind = "var",
        start_line = 3,
        end_line = 3,
        code_start_line = 3,
      })

      local start_line, end_line = formatter.find_group_boundaries(buf, symbol)
      assert.is_nil(start_line)
      assert.is_nil(end_line)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("get_group_keyword", function()
    it("should return 'var' for var group", function()
      local buf = create_go_buffer([[
package main

var (
    a = 1
    b = 2
)
]])
      local symbol = symbols.new({
        name = "a",
        kind = "var",
        start_line = 4,
        end_line = 4,
        code_start_line = 4,
      })

      assert.equals("var", formatter.get_group_keyword(buf, symbol))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return 'const' for const group", function()
      local buf = create_go_buffer([[
package main

const (
    A = 1
    B = 2
)
]])
      local symbol = symbols.new({
        name = "A",
        kind = "const",
        start_line = 4,
        end_line = 4,
        code_start_line = 4,
      })

      assert.equals("const", formatter.get_group_keyword(buf, symbol))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return 'type' for type group", function()
      local buf = create_go_buffer([[
package main

type (
    Foo struct{}
    Bar struct{}
)
]])
      local symbol = symbols.new({
        name = "Foo",
        kind = "struct",
        start_line = 4,
        end_line = 4,
        code_start_line = 4,
      })

      assert.equals("type", formatter.get_group_keyword(buf, symbol))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return nil for standalone symbol", function()
      local buf = create_go_buffer([[
package main

var a = 1
]])
      local symbol = symbols.new({
        name = "a",
        kind = "var",
        start_line = 3,
        end_line = 3,
        code_start_line = 3,
      })

      assert.is_nil(formatter.get_group_keyword(buf, symbol))
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)
end)

describe("group extraction and insertion", function()
  describe("extract then insert scenario", function()
    it("should correctly detect group membership after extraction", function()
      -- Setup: 3-item var group
      local buf = create_go_buffer([[
package main

var (
	a = 1
	b = 2
	c = 3
)
]])
      local parser = require("argus.parser")

      -- Parse initial symbols
      local initial_symbols = parser.parse_buffer(buf, "flat")

      -- Find symbol 'a'
      local sym_a = nil
      for _, s in ipairs(initial_symbols) do
        if s.name == "a" and s.kind == "var" then
          sym_a = s
          break
        end
      end
      assert.is_not_nil(sym_a, "Should find symbol 'a'")
      assert.is_true(formatter.is_in_group(buf, sym_a), "Symbol 'a' should initially be in group")

      -- Simulate extraction: modify buffer to have 'a' as standalone
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "package main",
        "",
        "var a = 1",
        "",
        "var (",
        "\tb = 2",
        "\tc = 3",
        ")",
      })

      -- Re-parse to get updated symbols
      local updated_symbols = parser.parse_buffer(buf, "flat")

      -- Find symbols after extraction
      local new_a, new_b, new_c
      for _, s in ipairs(updated_symbols) do
        if s.name == "a" and s.kind == "var" then new_a = s end
        if s.name == "b" and s.kind == "var" then new_b = s end
        if s.name == "c" and s.kind == "var" then new_c = s end
      end

      assert.is_not_nil(new_a, "Should find symbol 'a' after extraction")
      assert.is_not_nil(new_b, "Should find symbol 'b' after extraction")
      assert.is_not_nil(new_c, "Should find symbol 'c' after extraction")

      -- Verify 'a' is no longer in a group
      assert.is_false(formatter.is_in_group(buf, new_a), "Symbol 'a' should NOT be in group after extraction")

      -- Verify 'b' IS still in a group (this is the key test!)
      assert.is_true(formatter.is_in_group(buf, new_b), "Symbol 'b' should still be in group")

      -- Verify 'c' IS still in a group
      assert.is_true(formatter.is_in_group(buf, new_c), "Symbol 'c' should still be in group")

      -- Check line numbers are correct
      assert.equals(3, new_a.code_start_line, "Symbol 'a' should be at line 3")
      assert.equals(6, new_b.code_start_line, "Symbol 'b' should be at line 6")
      assert.equals(7, new_c.code_start_line, "Symbol 'c' should be at line 7")

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should allow inserting standalone symbol into group", function()
      -- Setup: standalone 'a' followed by 2-item group
      local buf = create_go_buffer([[
package main

var a = 1

var (
	b = 2
	c = 3
)
]])
      local parser = require("argus.parser")
      local actions = require("argus.actions")

      -- Parse symbols
      local symbols_list = parser.parse_buffer(buf, "flat")

      local sym_a, sym_b
      for _, s in ipairs(symbols_list) do
        if s.name == "a" and s.kind == "var" then sym_a = s end
        if s.name == "b" and s.kind == "var" then sym_b = s end
      end

      assert.is_not_nil(sym_a)
      assert.is_not_nil(sym_b)
      assert.is_false(formatter.is_in_group(buf, sym_a))
      assert.is_true(formatter.is_in_group(buf, sym_b))

      -- Call _insert_into_group to insert 'a' into the group at 'b' position
      actions._insert_into_group(buf, sym_a, sym_b, "down")

      -- Check the result
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local content = table.concat(lines, "\n")

      -- 'a' should now be in the group, and 'var a = 1' line should be gone
      assert.is_nil(content:match("var a = 1"), "Standalone 'var a = 1' should be removed")
      assert.is_not_nil(content:match("a = 1"), "Symbol 'a' should exist in group form")

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should preserve comments when inserting standalone with comment into group", function()
      -- Setup: standalone 'a' with comment, followed by 2-item group
      local buf = create_go_buffer([[
package main

// Comment for a
var a = 1

var (
	b = 2
	c = 3
)
]])
      local parser = require("argus.parser")
      local actions = require("argus.actions")

      -- Parse symbols
      local symbols_list = parser.parse_buffer(buf, "flat")

      local sym_a, sym_b
      for _, s in ipairs(symbols_list) do
        if s.name == "a" and s.kind == "var" then sym_a = s end
        if s.name == "b" and s.kind == "var" then sym_b = s end
      end

      assert.is_not_nil(sym_a)
      assert.is_not_nil(sym_b)

      -- Call _insert_into_group to insert 'a' into the group at 'b' position
      actions._insert_into_group(buf, sym_a, sym_b, "down")

      -- Check the result - comment should be preserved
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local content = table.concat(lines, "\n")

      -- Comment should be in the group now
      assert.is_not_nil(content:match("// Comment for a"), "Comment should be preserved")
      -- 'a' should be in the group
      assert.is_not_nil(content:match("a = 1"), "Symbol 'a' should exist in group form")
      -- Standalone 'var a' should be gone
      assert.is_nil(content:match("var a = 1"), "Standalone 'var a = 1' should be removed")

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)
end)

describe("symbols group functions", function()
  describe("get_group_siblings", function()
    it("should return only siblings within the same group", function()
      local buf = create_go_buffer([[
package main

var (
    a = 1
    b = 2
)

var c = 3
]])
      -- Create symbols that would be parsed
      local sym_a = symbols.new({
        name = "a",
        kind = "var",
        start_line = 4,
        end_line = 4,
        code_start_line = 4,
      })
      local sym_b = symbols.new({
        name = "b",
        kind = "var",
        start_line = 5,
        end_line = 5,
        code_start_line = 5,
      })
      local sym_c = symbols.new({
        name = "c",
        kind = "var",
        start_line = 8,
        end_line = 8,
        code_start_line = 8,
      })

      local all_symbols = { sym_a, sym_b, sym_c }
      local group_siblings, index = symbols.get_group_siblings(sym_a, all_symbols, buf)

      assert.equals(2, #group_siblings)
      assert.equals(1, index)
      assert.equals("a", group_siblings[1].name)
      assert.equals("b", group_siblings[2].name)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should return empty for symbol not in group", function()
      local buf = create_go_buffer([[
package main

var a = 1
var b = 2
]])
      local sym_a = symbols.new({
        name = "a",
        kind = "var",
        start_line = 3,
        end_line = 3,
        code_start_line = 3,
      })

      local group_siblings, index = symbols.get_group_siblings(sym_a, { sym_a }, buf)

      assert.equals(0, #group_siblings)
      assert.equals(0, index)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)
end)
