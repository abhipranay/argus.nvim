local parser = require("argus.parser")

-- Helper to create a buffer with Go code
local function create_go_buffer(content)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
  vim.bo[buf].filetype = "go"
  return buf
end

describe("parser", function()
  describe("parse_buffer", function()
    it("should return empty for non-go buffer", function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.bo[buf].filetype = "lua"

      local symbols = parser.parse_buffer(buf)

      assert.same({}, symbols)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should parse package declaration", function()
      local buf = create_go_buffer([[
package main
]])
      local symbols = parser.parse_buffer(buf)

      assert.equals(1, #symbols)
      assert.equals("main", symbols[1].name)
      assert.equals("package", symbols[1].kind)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should parse function declaration", function()
      local buf = create_go_buffer([[
package main

func Hello() {
}
]])
      local symbols = parser.parse_buffer(buf)

      -- Package + function
      assert.equals(2, #symbols)
      assert.equals("Hello", symbols[2].name)
      assert.equals("function", symbols[2].kind)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should parse struct type", function()
      local buf = create_go_buffer([[
package main

type Config struct {
    Host string
    Port int
}
]])
      local symbols = parser.parse_buffer(buf)

      assert.equals(2, #symbols)
      assert.equals("Config", symbols[2].name)
      assert.equals("struct", symbols[2].kind)
      -- Struct should have field children
      assert.equals(2, #symbols[2].children)
      assert.equals("Host", symbols[2].children[1].name)
      assert.equals("Port", symbols[2].children[2].name)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should parse interface type", function()
      local buf = create_go_buffer([[
package main

type Reader interface {
    Read(p []byte) (n int, err error)
}
]])
      local symbols = parser.parse_buffer(buf)

      assert.equals(2, #symbols)
      assert.equals("Reader", symbols[2].name)
      assert.equals("interface", symbols[2].kind)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should parse const declaration", function()
      local buf = create_go_buffer([[
package main

const MaxSize = 100
]])
      local symbols = parser.parse_buffer(buf)

      assert.equals(2, #symbols)
      assert.equals("MaxSize", symbols[2].name)
      assert.equals("const", symbols[2].kind)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should parse var declaration", function()
      local buf = create_go_buffer([[
package main

var logger *Logger
]])
      local symbols = parser.parse_buffer(buf)

      assert.equals(2, #symbols)
      assert.equals("logger", symbols[2].name)
      assert.equals("var", symbols[2].kind)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should parse grouped type declarations", function()
      local buf = create_go_buffer([[
package main

type (
    Config struct {
        Host string
    }

    Server struct {
        Port int
    }
)
]])
      local symbols = parser.parse_buffer(buf)

      -- Package + Config + Server
      assert.equals(3, #symbols)
      assert.equals("Config", symbols[2].name)
      assert.equals("Server", symbols[3].name)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should parse method and attach to receiver in hierarchy mode", function()
      local buf = create_go_buffer([[
package main

type Server struct {}

func (s *Server) Start() error {
    return nil
}
]])
      local symbols = parser.parse_buffer(buf, "hierarchy")

      -- Package + Server (with method as child)
      assert.equals(2, #symbols)
      assert.equals("Server", symbols[2].name)
      assert.equals(1, #symbols[2].children)
      assert.equals("Start", symbols[2].children[1].name)
      assert.equals("method", symbols[2].children[1].kind)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should keep method separate in flat mode", function()
      local buf = create_go_buffer([[
package main

type Server struct {}

func (s *Server) Start() error {
    return nil
}
]])
      local symbols = parser.parse_buffer(buf, "flat")

      -- Package + Server + Start method
      assert.equals(3, #symbols)
      assert.equals("Server", symbols[2].name)
      assert.equals("Start", symbols[3].name)
      assert.equals("method", symbols[3].kind)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should maintain file order in flat mode", function()
      local buf = create_go_buffer([[
package main

func First() {}

type Config struct {}

func Second() {}

func (c *Config) Method() {}

func Third() {}
]])
      local symbols = parser.parse_buffer(buf, "flat")

      local names = {}
      for _, s in ipairs(symbols) do
        table.insert(names, s.name)
      end

      assert.same({ "main", "First", "Config", "Second", "Method", "Third" }, names)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)
end)
