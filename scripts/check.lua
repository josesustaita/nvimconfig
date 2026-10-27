local function check()
  assert(vim.fn.exists(":Lazy") == 2, "lazy.nvim did not start")
  local config = require("lazy.core.config")
  for _, notice in ipairs(config.spec.notifs or {}) do
    assert(notice.level ~= vim.log.levels.ERROR, notice.msg)
  end
  local plugins = config.plugins
  assert(plugins["LazyVim"] and plugins["catppuccin"], "Editor plugins missing")
  assert(plugins["copilot.lua"], "Copilot extra did not load")
  require("lazy").load({ plugins = { "mini.animate" } })
  assert(type(require("mini.animate").setup) == "function", "Animation plugin failed")
  assert(vim.g.minianimate_disable == true, "Reduced motion was not applied")
  assert(vim.v.errmsg == "", vim.v.errmsg)
end
local ok, err = pcall(check)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
else
  print("LazyVim, Catppuccin, animation plugin, and reduced-motion checks passed")
  vim.cmd("qa!")
end
