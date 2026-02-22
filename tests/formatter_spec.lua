local formatter = require("argus.formatter")

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

describe("formatter", function()
  describe("is_public", function()
    it("should return true for uppercase names", function()
      assert.is_true(formatter.is_public("Foo"))
      assert.is_true(formatter.is_public("NewFoo"))
      assert.is_true(formatter.is_public("PublicMethod"))
    end)

    it("should return false for lowercase names", function()
      assert.is_false(formatter.is_public("foo"))
      assert.is_false(formatter.is_public("privateMethod"))
      assert.is_false(formatter.is_public("newFoo"))
    end)
  end)

  describe("is_constructor", function()
    it("should match NewXxx pattern for known types", function()
      local type_names = { Foo = true, Bar = true }
      assert.is_true(formatter.is_constructor("NewFoo", type_names))
      assert.is_true(formatter.is_constructor("NewBar", type_names))
    end)

    it("should match NewXxxFromYyy pattern", function()
      local type_names = { Foo = true }
      assert.is_true(formatter.is_constructor("NewFooFromConfig", type_names))
      assert.is_true(formatter.is_constructor("NewFooWithOptions", type_names))
    end)

    it("should not match if type not in list", function()
      local type_names = { Foo = true }
      assert.is_false(formatter.is_constructor("NewBar", type_names))
    end)

    it("should not match non-New functions", function()
      local type_names = { Foo = true }
      assert.is_false(formatter.is_constructor("CreateFoo", type_names))
      assert.is_false(formatter.is_constructor("Foo", type_names))
    end)
  end)

  describe("get_receiver_type", function()
    it("should extract type from pointer receiver", function()
      assert.equals("Foo", formatter.get_receiver_type("f *Foo"))
    end)

    it("should extract type from value receiver", function()
      assert.equals("Foo", formatter.get_receiver_type("f Foo"))
    end)

    it("should handle no receiver", function()
      assert.is_nil(formatter.get_receiver_type(nil))
    end)
  end)

  describe("format_buffer", function()
    it("should reorder sections according to template", function()
      local buf = create_go_buffer([[
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
]])
      formatter.format_buffer(buf)
      local result = get_buffer_content(buf)

      -- Verify order: package, imports, consts, vars, types, then functions
      local const_pos = result:find("const")
      local var_pos = result:find("var x")
      local type_pos = result:find("type Foo")
      local new_foo_pos = result:find("func NewFoo")
      local public_method_pos = result:find("PublicMethod")
      local private_method_pos = result:find("privateMethod")
      local public_func_pos = result:find("func PublicFunc")
      local private_func_pos = result:find("func privateFunc")

      -- consts before vars
      assert.is_true(const_pos < var_pos, "consts should come before vars")
      -- vars before types
      assert.is_true(var_pos < type_pos, "vars should come before types")
      -- type with its methods (constructor first)
      assert.is_true(type_pos < new_foo_pos, "type should come before constructor")
      assert.is_true(new_foo_pos < public_method_pos, "constructor should come before public methods")
      assert.is_true(public_method_pos < private_method_pos, "public methods should come before private methods")
      -- standalone functions at the end
      assert.is_true(private_method_pos < public_func_pos, "methods should come before standalone functions")
      assert.is_true(public_func_pos < private_func_pos, "public functions should come before private functions")

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should sort items inside const groups alphabetically", function()
      local buf = create_go_buffer([[
package main

const (
    Zebra = 3
    Apple = 1
    Mango = 2
)
]])
      formatter.format_buffer(buf)
      local result = get_buffer_content(buf)

      local apple_pos = result:find("Apple")
      local mango_pos = result:find("Mango")
      local zebra_pos = result:find("Zebra")

      assert.is_true(apple_pos < mango_pos, "Apple should come before Mango")
      assert.is_true(mango_pos < zebra_pos, "Mango should come before Zebra")

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should sort items inside var groups alphabetically", function()
      local buf = create_go_buffer([[
package main

var (
    zebra = 3
    apple = 1
    mango = 2
)
]])
      formatter.format_buffer(buf)
      local result = get_buffer_content(buf)

      local apple_pos = result:find("apple")
      local mango_pos = result:find("mango")
      local zebra_pos = result:find("zebra")

      assert.is_true(apple_pos < mango_pos, "apple should come before mango")
      assert.is_true(mango_pos < zebra_pos, "mango should come before zebra")

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should sort items inside type groups alphabetically", function()
      local buf = create_go_buffer([[
package main

type (
    Zebra struct{}
    Apple struct{}
    Mango struct{}
)
]])
      formatter.format_buffer(buf)
      local result = get_buffer_content(buf)

      local apple_pos = result:find("Apple")
      local mango_pos = result:find("Mango")
      local zebra_pos = result:find("Zebra")

      assert.is_true(apple_pos < mango_pos, "Apple should come before Mango")
      assert.is_true(mango_pos < zebra_pos, "Mango should come before Zebra")

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should keep standalone struct with its methods attached", function()
      local buf = create_go_buffer([[
package main

func (f *Foo) PublicB() {}
func (f *Foo) PublicA() {}

type Foo struct{}

func (f *Foo) privateB() {}
func (f *Foo) privateA() {}
func NewFoo() *Foo { return &Foo{} }
]])
      formatter.format_buffer(buf)
      local result = get_buffer_content(buf)

      -- type should be followed by constructor, then public methods (sorted), then private (sorted)
      local type_pos = result:find("type Foo")
      local new_foo_pos = result:find("func NewFoo")
      local public_a_pos = result:find("PublicA")
      local public_b_pos = result:find("PublicB")
      local private_a_pos = result:find("privateA")
      local private_b_pos = result:find("privateB")

      assert.is_true(type_pos < new_foo_pos, "type should come before constructor")
      assert.is_true(new_foo_pos < public_a_pos, "constructor should come before public methods")
      assert.is_true(public_a_pos < public_b_pos, "PublicA should come before PublicB (alphabetical)")
      assert.is_true(public_b_pos < private_a_pos, "public methods should come before private")
      assert.is_true(private_a_pos < private_b_pos, "privateA should come before privateB (alphabetical)")

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should sort public functions alphabetically", function()
      local buf = create_go_buffer([[
package main

func Zebra() {}
func Apple() {}
func Mango() {}
]])
      formatter.format_buffer(buf)
      local result = get_buffer_content(buf)

      local apple_pos = result:find("func Apple")
      local mango_pos = result:find("func Mango")
      local zebra_pos = result:find("func Zebra")

      assert.is_true(apple_pos < mango_pos, "Apple should come before Mango")
      assert.is_true(mango_pos < zebra_pos, "Mango should come before Zebra")

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should sort private functions alphabetically", function()
      local buf = create_go_buffer([[
package main

func zebra() {}
func apple() {}
func mango() {}
]])
      formatter.format_buffer(buf)
      local result = get_buffer_content(buf)

      local apple_pos = result:find("func apple")
      local mango_pos = result:find("func mango")
      local zebra_pos = result:find("func zebra")

      assert.is_true(apple_pos < mango_pos, "apple should come before mango")
      assert.is_true(mango_pos < zebra_pos, "mango should come before zebra")

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should preserve comments with their symbols", function()
      local buf = create_go_buffer([[
package main

// Zebra is a zebra function
func Zebra() {}

// Apple is an apple function
func Apple() {}
]])
      formatter.format_buffer(buf)
      local result = get_buffer_content(buf)

      -- Apple should come before Zebra, and comments should stay with their functions
      local apple_comment_pos = result:find("Apple is an apple")
      local apple_func_pos = result:find("func Apple")
      local zebra_comment_pos = result:find("Zebra is a zebra")
      local zebra_func_pos = result:find("func Zebra")

      assert.is_true(apple_comment_pos < apple_func_pos, "Apple comment should be before Apple func")
      assert.is_true(apple_func_pos < zebra_comment_pos, "Apple func should come before Zebra comment")
      assert.is_true(zebra_comment_pos < zebra_func_pos, "Zebra comment should be before Zebra func")

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should handle empty buffer gracefully", function()
      local buf = create_go_buffer("")
      -- Should not error
      formatter.format_buffer(buf)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should handle file with only package", function()
      local buf = create_go_buffer("package main")
      formatter.format_buffer(buf)
      local result = get_buffer_content(buf)
      assert.is_true(result:find("package main") ~= nil)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should place single blank line between sections", function()
      local buf = create_go_buffer([[
package main

const A = 1
var x = 1
func Foo() {}
]])
      formatter.format_buffer(buf)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

      -- Find blank lines - there should be exactly one between sections
      local blank_count = 0
      local prev_blank = false
      for _, line in ipairs(lines) do
        if line == "" then
          assert.is_false(prev_blank, "Should not have consecutive blank lines")
          blank_count = blank_count + 1
          prev_blank = true
        else
          prev_blank = false
        end
      end

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should handle orphan methods (receiver not in file)", function()
      local buf = create_go_buffer([[
package main

func (f *Unknown) Method() {}
func PublicFunc() {}
]])
      formatter.format_buffer(buf)
      local result = get_buffer_content(buf)

      -- Orphan method should be treated as a function
      assert.is_true(result:find("func %(f %*Unknown%) Method") ~= nil)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should handle multiple constructors for same type", function()
      local buf = create_go_buffer([[
package main

type Foo struct{}

func NewFooFromConfig(cfg Config) *Foo { return &Foo{} }
func NewFoo() *Foo { return &Foo{} }
func NewFooWithOptions(opts ...Option) *Foo { return &Foo{} }
]])
      formatter.format_buffer(buf)
      local result = get_buffer_content(buf)

      -- All constructors should be after the type and sorted
      local type_pos = result:find("type Foo")
      local new_foo_pos = result:find("func NewFoo%(%)") -- NewFoo() specifically
      local new_foo_config_pos = result:find("NewFooFromConfig")
      local new_foo_opts_pos = result:find("NewFooWithOptions")

      assert.is_true(type_pos < new_foo_pos, "type should come before constructors")
      -- Constructors should be sorted alphabetically
      assert.is_true(new_foo_pos < new_foo_config_pos, "NewFoo should come before NewFooFromConfig")
      assert.is_true(new_foo_config_pos < new_foo_opts_pos, "NewFooFromConfig should come before NewFooWithOptions")

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should keep methods for types in groups in separate sections", function()
      local buf = create_go_buffer([[
package main

type (
    Foo struct{}
    Bar struct{}
)

func (f *Foo) Method() {}
func (b *Bar) Method() {}
func PublicFunc() {}
]])
      formatter.format_buffer(buf)
      local result = get_buffer_content(buf)

      -- Types in group should have methods in public_methods/private_methods sections
      local type_group_pos = result:find("type %(")
      local foo_method_pos = result:find("%(f %*Foo%) Method")
      local bar_method_pos = result:find("%(b %*Bar%) Method")
      local public_func_pos = result:find("func PublicFunc")

      -- Methods should be after type group but before standalone functions
      assert.is_true(type_group_pos < foo_method_pos, "type group should come before Foo method")
      assert.is_true(foo_method_pos < public_func_pos or bar_method_pos < public_func_pos,
        "methods should come before standalone functions")

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should always keep package and imports at the top regardless of template", function()
      -- Override config with a weird template that puts functions first
      local config = require("argus.config")
      local original_template = config.get().format_template
      config.get().format_template = {
        "public_functions",  -- Try to put functions first
        "package",           -- Package later
        "imports",           -- Imports later
        "consts",
        "types",
      }

      local buf = create_go_buffer([[
package main

import "fmt"

const X = 1
func Foo() {}
]])
      formatter.format_buffer(buf)
      local result = get_buffer_content(buf)

      -- Package should always be first
      local pkg_pos = result:find("package main")
      local import_pos = result:find("import")
      local const_pos = result:find("const")
      local func_pos = result:find("func Foo")

      assert.is_true(pkg_pos < import_pos, "package must always be at the very top")
      assert.is_true(import_pos < const_pos, "imports must always come right after package")
      assert.is_true(import_pos < func_pos, "imports must always come before any declarations")

      -- Restore original template
      config.get().format_template = original_template

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)
end)
