# Theme contract

One engine, `dotfiles-theme` (stowed by the `desktop` layer's `theme` package),
renders every theme output. Window manager layers only contribute templates.

## Palettes

`palettes/<id>.conf` is versioned data. It is parsed, never sourced, with a
strict `key=value` schema:

- `schema=1`, `id` (must match the file name), `family`, `flavour` and
  `accent_name` metadata;
- the 26 Catppuccin palette colors as `#rrggbb` values (either case);
- resolved semantic roles: `background`, `background_alt`, `background_deep`,
  `surface`, `surface_hover`, `foreground`, `foreground_muted`, `accent`,
  `urgent`, `warning`, `success`.

Keys may appear only once; unknown or missing keys are errors. The default
theme is `catppuccin-mocha-pink`.

## Templates

Templates are plain files where `{{key}}` becomes the palette value (`#89b4fa`)
and `{{key.raw}}` the value without `#` (`89b4fa`), so formats such as
`0x{{accent.raw}}ff` or `rgb({{accent.raw}})` are written in the template. Any
other `{{...}}` marker fails the render.

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
    ├── metadata
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
