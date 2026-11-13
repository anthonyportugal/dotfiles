-- The "dotfiles" colorscheme (colors/dotfiles.lua) follows the active palette
-- when dotfiles-theme has rendered one; otherwise LazyVim's tokyonight is used.
local palette = (vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state"))
  .. "/dotfiles/theme/current/nvim/palette.lua"

return {
  { "nvim-mini/mini.base16", lazy = true },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        if not ((vim.uv or vim.loop).fs_stat(palette) and pcall(vim.cmd.colorscheme, "dotfiles")) then
          vim.cmd.colorscheme("tokyonight")
        end
      end,
    },
  },
}
