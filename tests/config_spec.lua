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
end)
