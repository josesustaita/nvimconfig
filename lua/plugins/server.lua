if vim.env.NVIM_SERVER_MODE ~= "1" then
  return {}
end

-- Remote administration should not install language toolchains or compile parsers.
local disabled = {
  "zbirenbaum/copilot.lua",
  "nvim-treesitter/nvim-treesitter",
  "nvim-treesitter/nvim-treesitter-textobjects",
  "windwp/nvim-ts-autotag",
  "neovim/nvim-lspconfig",
  "mason-org/mason.nvim",
  "mason-org/mason-lspconfig.nvim",
  "stevearc/conform.nvim",
  "mfussenegger/nvim-lint",
  "saghen/blink.cmp",
}
local plugins = {}
for _, plugin in ipairs(disabled) do
  plugins[#plugins + 1] = { plugin, enabled = false }
end
return plugins
