-- Let deferred parser/Mason tasks start, then finish before the image is saved.
vim.wait(1000)
local registry = require("mason-registry")
local done = vim.wait(180000, function()
  for _, package in ipairs(registry.get_all_packages()) do
    if package:is_installing() then
      return false
    end
  end
  return true
end, 100)
if not done then
  io.stderr:write("Timed out while provisioning language tools\n")
  vim.cmd("cquit 1")
else
  dofile(vim.fn.stdpath("config") .. "/scripts/check.lua")
end
