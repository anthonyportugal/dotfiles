-- :colorscheme dotfiles — the active dotfiles palette, rendered by
-- dotfiles-theme (desktop layer) into the state directory. mini.base16 builds
-- the full highlight set (editor, treesitter, LSP and plugin integrations) from
-- 16 colors; the palette's own roles then refine the groups below.
local state = vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
local file = state .. "/dotfiles/theme/current/nvim/palette.lua"
local ok, p = pcall(dofile, file)
if not ok or type(p) ~= "table" then
  error("dotfiles colorscheme: no rendered palette at " .. file .. " (run dotfiles-theme render)")
end

-- 'background' follows the palette: light when the background is bright.
local r, g, b = p.background:match("#(%x%x)(%x%x)(%x%x)")
local luminance = (0.2126 * tonumber(r, 16) + 0.7152 * tonumber(g, 16) + 0.0722 * tonumber(b, 16)) / 255
vim.o.background = luminance > 0.5 and "light" or "dark"

vim.cmd("highlight clear")
require("mini.base16").setup({ palette = p.base16 })

local s = p.syntax
local set = function(group, spec)
  vim.api.nvim_set_hl(0, group, spec)
end

-- Editor chrome.
set("CursorLineNr", { fg = p.accent, bold = true })
set("Visual", { bg = p.selection_bg, fg = p.selection_fg })
set("FloatBorder", { fg = p.border, bg = p.background_alt })
set("NormalFloat", { fg = p.foreground, bg = p.background_alt })
set("WinSeparator", { fg = p.border })
set("Search", { fg = p.accent_fg, bg = p.accent })
set("IncSearch", { fg = p.accent_fg, bg = p.warning })
set("MatchParen", { fg = p.accent, bold = true })

-- Diagnostics use the palette's status roles.
for name, color in pairs({ Error = p.urgent, Warn = p.warning, Info = p.info, Hint = p.success, Ok = p.success }) do
  set("Diagnostic" .. name, { fg = color })
  set("DiagnosticUnderline" .. name, { sp = color, undercurl = true })
end

-- Syntax roles (treesitter captures link to these standard groups).
set("Comment", { fg = s.comment, italic = true })
set("String", { fg = s.string })
set("Number", { fg = s.number })
set("Constant", { fg = s.constant })
set("Function", { fg = s["function"] })
set("Type", { fg = s.type })
set("Keyword", { fg = s.keyword })
set("Statement", { fg = s.keyword })
set("Operator", { fg = s.operator })
set("Delimiter", { fg = s.punctuation })
set("Identifier", { fg = s.variable })
set("Tag", { fg = s.tag })
set("@variable", { fg = s.variable })
set("@property", { fg = s.property })
set("@string.regexp", { fg = s.regex })
set("@tag", { fg = s.tag })
set("@punctuation", { fg = s.punctuation })

vim.g.colors_name = "dotfiles"
