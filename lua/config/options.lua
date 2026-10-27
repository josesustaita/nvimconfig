-- Motion is optional; use NVIM_REDUCED_MOTION=1 for a still editor.
vim.g.minianimate_disable = vim.env.NVIM_REDUCED_MOTION == "1"
vim.g.snacks_animate = false -- mini.animate owns scrolling and resize animations
vim.opt.termguicolors = true
if vim.env.NVIM_SERVER_MODE == "1" then
  vim.g.lazyvim_picker = "snacks"
  vim.g.lazyvim_explorer = "snacks"
end
