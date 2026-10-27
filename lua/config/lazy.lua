local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local output = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", "https://github.com/folke/lazy.nvim.git", lazypath })
  if vim.v.shell_error ~= 0 then
    error("Could not bootstrap lazy.nvim:\n" .. output)
  end
end
vim.opt.rtp:prepend(lazypath)
require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", version = "v16.0.1", import = "lazyvim.plugins" },
    { import = "plugins" },
  },
  defaults = { lazy = false, version = false },
  install = { colorscheme = { "catppuccin" } },
  checker = { enabled = false },
  performance = { rtp = { disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" } } },
})
