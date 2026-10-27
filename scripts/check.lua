local function check()
  assert(vim.fn.exists(":Lazy") == 2, "lazy.nvim did not start")
  local config = require("lazy.core.config")
  for _, notice in ipairs(config.spec.notifs or {}) do
    assert(notice.level ~= vim.log.levels.ERROR, notice.msg)
  end
  local plugins = config.plugins
  local bootstrap_lock = vim.g.jose_nvim_lock
    and vim.json.decode(table.concat(vim.g.jose_nvim_lock, "\n"))
  for name, plugin in pairs(plugins) do
    assert(plugin._.installed, "Plugin was not installed: " .. name)
    if bootstrap_lock and bootstrap_lock[name] then
      local info = require("lazy.manage.git").info(plugin.dir)
      assert(info and info.commit == bootstrap_lock[name].commit, "Plugin revision does not match lockfile: " .. name)
    end
    for _, task in ipairs(plugin._.tasks or {}) do
      assert(not task:has_errors(), name .. ": " .. task:output(vim.log.levels.ERROR))
    end
  end
  assert(plugins["LazyVim"] and plugins["catppuccin"], "Editor plugins missing")
  assert(plugins["copilot.lua"], "Copilot extra did not load")
  for _, name in ipairs({
    "cmake-tools.nvim",
    "dial.nvim",
    "markdown-preview.nvim",
    "mini.hipatterns",
    "render-markdown.nvim",
    "venv-selector.nvim",
    "vim-dadbod",
    "vim-dadbod-completion",
    "vim-dadbod-ui",
    "yanky.nvim",
  }) do
    assert(plugins[name] and plugins[name]._.installed, "Personal plugin was not installed: " .. name)
  end
  for _, extra in ipairs({ "formatting.prettier", "lang.docker", "lang.toml", "lang.yaml" }) do
    assert(LazyVim.has_extra(extra), "Personal extra did not load: " .. extra)
  end
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
  print("LazyVim, personal plugins, Catppuccin, animation plugin, and reduced-motion checks passed")
  vim.cmd("qa!")
end
