return {
  {
    "nvim-mini/mini.animate",
    version = false,
    event = "VeryLazy",
    opts = function()
      local animate = require("mini.animate")
      return {
        cursor = { enable = false },
        scroll = { timing = animate.gen_timing.linear({ duration = 120, unit = "total" }) },
        resize = { timing = animate.gen_timing.linear({ duration = 100, unit = "total" }) },
        open = { enable = false },
        close = { enable = false },
      }
    end,
  },
}
