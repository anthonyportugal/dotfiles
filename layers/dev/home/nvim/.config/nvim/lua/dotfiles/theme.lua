-- Where dotfiles-theme (desktop layer) renders Neovim's palette; shared by the
-- colorscheme option (lua/plugins/colorscheme.lua) and colors/dotfiles.lua.
local M = {}

function M.palette_path()
  local state = vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
  return state .. "/dotfiles/theme/current/nvim/palette.lua"
end

return M
