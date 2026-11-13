-- lazy.nvim is the plugin manager; LazyVim is a plugin set built on top of it.
-- On first start lazy.nvim clones itself, then installs every plugin below and
-- records the exact commits in lazy-lock.json (next to this config, not in the
-- dotfiles repository).
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- LazyVim core: editor defaults, LSP, completion, treesitter, picker, git.
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },

    -- Extras: one per language or tool. Each one wires its language server,
    -- treesitter parsers and formatter/linter; Mason installs the servers.
    -- Add a stack later by adding its extra here (e.g. lang.dart for Flutter),
    -- or try one interactively with :LazyExtras.
    { import = "lazyvim.plugins.extras.lang.typescript" }, -- TypeScript, JavaScript, React (vtsls)
    { import = "lazyvim.plugins.extras.lang.vue" },
    { import = "lazyvim.plugins.extras.lang.angular" },
    { import = "lazyvim.plugins.extras.lang.astro" },
    { import = "lazyvim.plugins.extras.lang.tailwind" },
    { import = "lazyvim.plugins.extras.lang.go" },
    { import = "lazyvim.plugins.extras.lang.rust" }, -- Tauri backend
    { import = "lazyvim.plugins.extras.lang.json" },
    { import = "lazyvim.plugins.extras.lang.yaml" },
    { import = "lazyvim.plugins.extras.lang.toml" },
    { import = "lazyvim.plugins.extras.lang.docker" },
    { import = "lazyvim.plugins.extras.lang.markdown" },
    { import = "lazyvim.plugins.extras.formatting.prettier" },
    { import = "lazyvim.plugins.extras.linting.eslint" },
    { import = "lazyvim.plugins.extras.dap.core" }, -- debugger (delve for Go)
    { import = "lazyvim.plugins.extras.test.core" }, -- test runner

    -- Local plugins and overrides (lua/plugins/*.lua).
    { import = "plugins" },
  },
  defaults = {
    -- Only LazyVim's own plugins are lazy-loaded; local ones load at startup.
    lazy = false,
    -- Track the latest commit: many plugins have stale releases.
    version = false,
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  -- Check for plugin updates in the background without notifying; :Lazy shows them.
  checker = { enabled = true, notify = false },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
    },
  },
})
