vim.keymap.set("n", "<leader>ua", function()
  vim.g.minianimate_disable = not vim.g.minianimate_disable
  vim.notify("Animations " .. (vim.g.minianimate_disable and "off" or "on"))
end, { desc = "Toggle editor animations" })

vim.keymap.set("i", "<C-j>", function()
  local ok, suggestion = pcall(require, "copilot.suggestion")
  if ok and suggestion.is_visible() then
    suggestion.accept()
  end
end, { desc = "Accept Copilot suggestion" })
