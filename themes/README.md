# Theme contract

One engine, `dotfiles-theme` (stowed by the `desktop` layer's `theme` package),
renders every theme output. Window manager layers only contribute templates.

## Palettes

`palettes/<id>.conf` is versioned data. It is parsed, never sourced, with a
strict `key=value` schema. The engine accepts `schema=2` only; every key below
is required exactly once, and unknown, missing or duplicate keys are errors.

| Group | Keys | Value |
|-------|------|-------|
| Metadata | `schema`, `id` (must match the file name), `family`, `flavour`, `accent_name` | `2`; lower-case names (`[a-z0-9-]`) |
| Surfaces | `background_deep`, `background_alt`, `background`, `surface`, `surface_hover`, `surface_strong` | color |
| Text | `foreground`, `foreground_muted`, `foreground_subtle`, `foreground_disabled`, `border` | color |
| Accent and status | `accent`, `accent_fg`, `urgent`, `warning`, `success`, `info` | color |
| Selection and cursor | `selection_bg`, `selection_fg`, `cursor`, `cursor_fg` | color |
| ANSI | `ansi_{black,red,green,yellow,blue,magenta,cyan,white}` and `ansi_bright_*` for the same 8 | color |
| Syntax | `syntax_{keyword,string,number,constant,function,type,property,tag,operator,regex,variable,punctuation,comment}` | color |
| Decorative hues | `hue_{red,orange,yellow,green,teal,cyan,blue,indigo,purple,pink,rose,maroon}` | color |
| Fonts | `font_mono`, `font_text`, `font_display`, `font_inscription` | family name, `^[A-Za-z0-9][A-Za-z0-9 ]*$` |
| Cursor | `cursor_theme`, `cursor_size` | `^[A-Za-z0-9][A-Za-z0-9._-]*$`; `^[0-9]{2,3}$` |

Colors are `#rrggbb` (either case). `accent_name` names the accent within its
family; the GNOME accent color is derived from it. The default theme is
`catppuccin-mocha-pink`.

The Catppuccin palettes map Mocha onto these roles: `background_deep`/`accent_fg`
= crust, `background_alt` = mantle, `background`/`cursor_fg` = base, `surface`
= surface0, `surface_hover` = surface1, `surface_strong`/`border`/`selection_bg`
= surface2, `foreground`/`selection_fg` = text, `foreground_muted` = subtext0,
`foreground_subtle` = overlay1, `foreground_disabled` = overlay0, `info` =
sapphire, `cursor` = the accent; the ANSI colors match the foot terminal
(magenta = pink, cyan = teal, white = subtext1, bright black = surface2, bright
white = text); `hue_rose` = flamingo, `hue_indigo` = lavender, `hue_purple` =
mauve, `hue_cyan` = sky.

## Templates

Templates are plain files where `{{key}}` becomes the palette value of any key
(`#89b4fa`, `JetBrainsMono Nerd Font`) and, for colors only, `{{key.raw}}` the
value without `#` (`89b4fa`), so formats such as `0x{{accent.raw}}ff` or
`rgb({{accent.raw}})` are written in the template. Any other `{{...}}` marker,
including `.raw` on a font or cursor key, fails the render.

- `templates/` holds the outputs every desktop shares (`gtk.css`,
  `yazi/flavor.toml`).
- A window manager layer stows its own templates into
  `~/.local/share/dotfiles/theme/templates/<wm>/` and may stow an executable
  `~/.local/share/dotfiles/theme/reload.d/<wm>` that reloads its session after
  `dotfiles-theme set`. The hook receives the active directory in
  `DOTFILES_THEME_DIR`.

## Rendered state

```text
$XDG_STATE_HOME/dotfiles/theme/
├── selected                      # saved theme id
├── current -> <id>-<digest>      # promoted atomically
└── <id>-<digest>/
    ├── gtk.css                   # imported by ~/.config/gtk-{3.0,4.0}/gtk.css
    ├── yazi/flavor.toml          # linked as ~/.config/yazi/flavors/theme.yazi
    ├── background
    ├── metadata                  # schema=2, id, family, flavour, accent_name
    └── <wm>/...                  # one directory per installed WM
```

The digest covers the palette, the engine and every template with its path, so
editing, adding or renaming a template renders a new revision. The `desktop`
layer renders on apply; `DOTFILES_THEME=<id>` overrides the saved selection for
one command.

## Commands

```text
dotfiles-theme list | current | set <id> | render [id] | validate [id] | path
```

`set` renders, saves the selection, syncs the GNOME accent color and runs every
reload hook. `path` renders first when nothing is active yet.
