local plugins = {
  {
    "jackMort/ChatGPT.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("chatgpt").setup({
        api_key_cmd = "echo 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",
      })
    end,
  },
  {
    "github/copilot.vim",
  },
}
return plugins
