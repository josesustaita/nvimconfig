return {
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = {
      { "windwp/nvim-autopairs" },
      { "windwp/nvim-ts-autotag" },
    },
    opts = {
      highlight = { enable = true },
      autopairs = { enable = true },
      autotag = { enable = true },
      indent = { enable = true },
    },
  },
}
