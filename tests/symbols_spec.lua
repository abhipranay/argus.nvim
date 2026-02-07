local symbols = require("argus.symbols")

describe("symbols", function()
  describe("new", function()
    it("should create a symbol with default values", function()
      local sym = symbols.new({ name = "TestFunc" })

      assert.equals("TestFunc", sym.name)
      assert.equals("function", sym.kind)
      assert.equals("", sym.icon)
      assert.equals(0, sym.start_line)
      assert.equals(0, sym.end_line)
      assert.is_nil(sym.receiver)
      assert.same({}, sym.children)
      assert.is_nil(sym.parent)
      assert.equals(false, sym.collapsed)
    end)

    it("should create a symbol with provided values", function()
      local sym = symbols.new({
        name = "MyMethod",
        kind = "method",
        icon = "󰆧",
        start_line = 10,
        end_line = 20,
        code_start_line = 12,
        receiver = "s *Server",
        signature = "(ctx context.Context)",
      })

      assert.equals("MyMethod", sym.name)
      assert.equals("method", sym.kind)
      assert.equals("󰆧", sym.icon)
      assert.equals(10, sym.start_line)
      assert.equals(20, sym.end_line)
      assert.equals(12, sym.code_start_line)
      assert.equals("s *Server", sym.receiver)
      assert.equals("(ctx context.Context)", sym.signature)
    end)
  end)

  describe("display_name", function()
    it("should return name for simple symbol", function()
      local sym = symbols.new({ name = "Config", kind = "struct" })
      assert.equals("Config", symbols.display_name(sym))
    end)

    it("should include signature for function", function()
      local sym = symbols.new({
        name = "NewConfig",
        kind = "function",
        signature = "(opts Options)",
      })
      assert.equals("NewConfig(opts Options)", symbols.display_name(sym))
    end)

    it("should include receiver for method", function()
      local sym = symbols.new({
        name = "Start",
        kind = "method",
        receiver = "s *Server",
        signature = "()",
      })
      assert.equals("(s *Server) Start()", symbols.display_name(sym))
    end)

    it("should include type for field", function()
      local sym = symbols.new({
        name = "Port",
        kind = "field",
        signature = "int",
      })
      assert.equals("Port int", symbols.display_name(sym))
    end)
  end)

  describe("add_child", function()
    it("should add child and set parent reference", function()
      local parent = symbols.new({ name = "Server", kind = "struct" })
      local child = symbols.new({ name = "Start", kind = "method" })

      symbols.add_child(parent, child)

      assert.equals(1, #parent.children)
      assert.equals(child, parent.children[1])
      assert.equals(parent, child.parent)
    end)
  end)

  describe("flatten", function()
    it("should return flat list of symbols", function()
      local parent = symbols.new({ name = "Server", kind = "struct" })
      local child1 = symbols.new({ name = "Start", kind = "method" })
      local child2 = symbols.new({ name = "Stop", kind = "method" })
      symbols.add_child(parent, child1)
      symbols.add_child(parent, child2)

      local flat = symbols.flatten({ parent })

      assert.equals(3, #flat)
      assert.equals("Server", flat[1].name)
      assert.equals("Start", flat[2].name)
      assert.equals("Stop", flat[3].name)
    end)

    it("should skip children of collapsed nodes", function()
      local parent = symbols.new({ name = "Server", kind = "struct", collapsed = true })
      local child = symbols.new({ name = "Start", kind = "method" })
      symbols.add_child(parent, child)

      local flat = symbols.flatten({ parent }, false)

      assert.equals(1, #flat)
      assert.equals("Server", flat[1].name)
    end)

    it("should include children of collapsed nodes when requested", function()
      local parent = symbols.new({ name = "Server", kind = "struct", collapsed = true })
      local child = symbols.new({ name = "Start", kind = "method" })
      symbols.add_child(parent, child)

      local flat = symbols.flatten({ parent }, true)

      assert.equals(2, #flat)
    end)
  end)

  describe("get_siblings", function()
    it("should return siblings for top-level symbol", function()
      local sym1 = symbols.new({ name = "Func1", kind = "function" })
      local sym2 = symbols.new({ name = "Func2", kind = "function" })
      local sym3 = symbols.new({ name = "Func3", kind = "function" })
      local all = { sym1, sym2, sym3 }

      local siblings, index = symbols.get_siblings(sym2, all)

      assert.equals(3, #siblings)
      assert.equals(2, index)
    end)

    it("should return siblings for child symbol", function()
      local parent = symbols.new({ name = "Server", kind = "struct" })
      local child1 = symbols.new({ name = "Start", kind = "method" })
      local child2 = symbols.new({ name = "Stop", kind = "method" })
      symbols.add_child(parent, child1)
      symbols.add_child(parent, child2)

      local siblings, index = symbols.get_siblings(child2, { parent })

      assert.equals(2, #siblings)
      assert.equals(2, index)
    end)
  end)

  describe("line_count", function()
    it("should calculate correct line count", function()
      local sym = symbols.new({
        name = "Test",
        start_line = 10,
        end_line = 25,
      })

      assert.equals(16, symbols.line_count(sym))
    end)
  end)

  describe("find_by_source_line", function()
    it("should find symbol containing line", function()
      local sym1 = symbols.new({ name = "Func1", start_line = 1, end_line = 10 })
      local sym2 = symbols.new({ name = "Func2", start_line = 12, end_line = 20 })

      local found = symbols.find_by_source_line({ sym1, sym2 }, 5)

      assert.is_not_nil(found)
      assert.equals("Func1", found.name)
    end)

    it("should return nil for line outside any symbol", function()
      local sym = symbols.new({ name = "Func1", start_line = 1, end_line = 10 })

      local found = symbols.find_by_source_line({ sym }, 15)

      assert.is_nil(found)
    end)
  end)
end)
