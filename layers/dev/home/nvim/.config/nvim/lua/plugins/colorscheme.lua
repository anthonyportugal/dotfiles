-- The "dotfiles" colorscheme (colors/dotfiles.lua) follows the active palette
-- when dotfiles-theme has rendered one; otherwise LazyVim's tokyonight is used.
return {
  { "nvim-mini/mini.base16", lazy = true },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        local palette = require("dotfiles.theme").palette_path()
        if not ((vim.uv or vim.loop).fs_stat(palette) and pcall(vim.cmd.colorscheme, "dotfiles")) then
          vim.cmd.colorscheme("tokyonight")
        end
      end,
    },
  },
}
