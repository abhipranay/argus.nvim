local config = require("argus.config")

describe("config", function()
  before_each(function()
    -- Reset config before each test
    config.options = {}
  end)

  describe("setup", function()
    it("should use default values when no options provided", function()
      config.setup()
      local cfg = config.get()

      assert.equals("right", cfg.position)
      assert.equals(40, cfg.width)
      assert.equals(true, cfg.auto_close)
      assert.equals(true, cfg.show_line_numbers)
      assert.equals(false, cfg.auto_preview)
      assert.equals(true, cfg.follow_cursor)
      assert.equals("flat", cfg.view_mode)
    end)

    it("should merge user options with defaults", function()
      config.setup({
        position = "left",
        width = 50,
      })
      local cfg = config.get()

      assert.equals("left", cfg.position)
      assert.equals(50, cfg.width)
      -- Defaults should still be present
      assert.equals(true, cfg.auto_close)
    end)

    it("should allow custom keymaps", function()
      config.setup({
        keymaps = {
          close = "x",
          jump = "o",
        },
      })
      local cfg = config.get()

      assert.equals("x", cfg.keymaps.close)
      assert.equals("o", cfg.keymaps.jump)
      -- Other keymaps should keep defaults
      assert.equals("K", cfg.keymaps.move_up)
    end)
  end)

  describe("icons", function()
    it("should have all required icon keys in default preset", function()
      local icons = config.icon_presets.default
      local required_keys = {
        "package", "function", "method", "struct",
        "interface", "type", "const", "var", "field",
        "collapsed", "expanded"
      }

      for _, key in ipairs(required_keys) do
        assert.is_not_nil(icons[key], "Missing icon: " .. key)
      end
    end)

    it("should return correct icon for symbol kind", function()
      config.setup()
      local icon = config.get_icon("function")
      assert.is_not_nil(icon)
      assert.is_true(#icon > 0)
    end)

    it("should return empty string for unknown kind", function()
      config.setup()
      local icon = config.get_icon("unknown_kind")
      assert.equals("", icon)
    end)
  end)

  describe("presets", function()
    it("should return default preset for unknown name", function()
      local preset = config.get_preset("nonexistent")
      assert.same(config.icon_presets.default, preset)
    end)

    it("should return correct preset by name", function()
      local material = config.get_preset("material")
      assert.same(config.icon_presets.material, material)
    end)

    it("should have all presets with same keys", function()
      local default_keys = vim.tbl_keys(config.icon_presets.default)
      table.sort(default_keys)

      for name, preset in pairs(config.icon_presets) do
        local keys = vim.tbl_keys(preset)
        table.sort(keys)
        assert.same(default_keys, keys, "Preset '" .. name .. "' has different keys")
      end
    end)
  end)

  describe("mini.icons integration", function()
    it("should allow setting icons to 'mini' string", function()
      config.setup({ icons = "mini" })
      local cfg = config.get()
      assert.equals(config.MINI_ICONS, cfg.icons)
    end)

    it("should provide is_mini_icons_available function", function()
      assert.is_function(config.is_mini_icons_available)
    end)

    it("should provide uses_mini_icons function", function()
      assert.is_function(config.uses_mini_icons)
      config.setup({ icons = "mini" })
      assert.is_true(config.uses_mini_icons())
      config.setup({ icons = "default" })
      assert.is_false(config.uses_mini_icons())
    end)

    it("should provide get_mini_icon function", function()
      assert.is_function(config.get_mini_icon)
    end)

    it("should return nil from get_mini_icon when mini.icons not available", function()
      -- Force mini.icons to be unavailable
      package.loaded["mini.icons"] = nil
      local icon, hl = config.get_mini_icon("function")
      if not config.is_mini_icons_available() then
        assert.is_nil(icon)
      end
    end)

    it("should map argus kinds to LSP kinds correctly", function()
      -- Test the mapping exists
      assert.is_not_nil(config.lsp_kind_map)
      assert.equals("Function", config.lsp_kind_map["function"])
      assert.equals("Method", config.lsp_kind_map["method"])
      assert.equals("Struct", config.lsp_kind_map["struct"])
      assert.equals("Interface", config.lsp_kind_map["interface"])
      assert.equals("Constant", config.lsp_kind_map["const"])
      assert.equals("Variable", config.lsp_kind_map["var"])
      assert.equals("Field", config.lsp_kind_map["field"])
      assert.equals("Module", config.lsp_kind_map["package"])
    end)

    it("should get_preset return MINI_ICONS for 'mini'", function()
      local preset = config.get_preset("mini")
      assert.equals(config.MINI_ICONS, preset)
    end)

    it("should fall back to default icons for collapsed/expanded with mini", function()
      config.setup({ icons = "mini" })
      -- collapsed/expanded don't have LSP equivalents, should fall back
      local collapsed_icon = config.get_icon("collapsed")
      local expanded_icon = config.get_icon("expanded")
      assert.equals(config.icon_presets.default.collapsed, collapsed_icon)
      assert.equals(config.icon_presets.default.expanded, expanded_icon)
    end)

    it("should allow icons as preset name string", function()
      config.setup({ icons = "material" })
      local cfg = config.get()
      assert.same(config.icon_presets.material, cfg.icons)
    end)
  end)
end)
