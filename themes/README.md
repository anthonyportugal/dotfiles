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
family; the GNOME accent color is derived from it. `cursor_theme` names an
Xcursor theme (Bibata comes from the desktop layer's external downloads) and
reaches GTK (gsettings on `set`), MangoWM (`cursor_theme`, `cursor_size` and
`XCURSOR_THEME`/`XCURSOR_SIZE` in its rendered `mango.conf`) and bspwm
(`Xcursor.theme`/`Xcursor.size` resources from its rendered `bspwm.env`); a
theme that is not installed falls back to the default cursor. The default theme is
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

### Families

| Family | Ids | Source |
|--------|-----|--------|
| Catppuccin | `catppuccin-mocha-<accent>`, 14 accents | hand-written from the Catppuccin Mocha palette |
| Sanctuary | `sanctuary-<flavor>-<pigment>`: flavors `compline`, `vespers`, `matins` (`lauds` is light and left out); pigments `amber amethyst azure cobalt ember gilt indigo murrey rose ruby verdure viridian` | generated from `@sanctuary-ds/tokens` |

The Sanctuary palettes are generated, never edited by hand.
`tools/generate-sanctuary-palettes` (python3, standard library) reads
`sources/sanctuary-ds-tokens-0.3.0/palette.json` (`dist/palette.json` of
`@sanctuary-ds/tokens` 0.3.0, vendored unchanged), refuses it unless its
sha256 is the pinned
`f6a05e1b2bb3effd84236bd479ea4ba7a91fd2c39f412f64469021ac4bd5bb24`, and
writes the 36 `palettes/sanctuary-*.conf`, removing any other
`sanctuary-*.conf`:

```sh
themes/tools/generate-sanctuary-palettes          # regenerate
themes/tools/generate-sanctuary-palettes --check  # writes nothing; exit 1 and lists each difference
```

`tests/sanctuary-smoke.sh` runs `--check`, so the committed palettes always
equal the generator output. To move to another release, vendor it under a new
`sources/sanctuary-ds-tokens-<version>/` and update the path and hash in the
generator.

Sanctuary roles (one flavor's `colors`, `<p>` = the pigment): `background_deep`
and `background_alt` = `surface-sunken`, `background` = `surface`, `surface` =
`surface-raised-2`, `surface_hover` = `surface-raised-3`, `surface_strong` =
`surface-raised-4`, `foreground`/`_muted`/`_subtle`/`_disabled` =
`text`/`text-muted`/`text-subtle`/`text-disabled`, `border` = `lead`,
`accent`/`cursor` = `glass-<p>`, `accent_fg`/`cursor_fg` = `glass-<p>-on`,
`selection_bg`/`selection_fg` = `glass-<p>-pane`/`glass-<p>-on-pane`,
`urgent` = `danger`, `warning`, `success`, `info`, the ANSI and syntax roles
= `ansi-*` and `syntax-*`; hues red/orange/yellow/green/teal/cyan/blue/indigo/
purple/pink/rose/maroon = `glass-` ruby/ember/gilt/verdure/viridian/azure/
cobalt/indigo/amethyst/rose/amber/murrey. Fonts: `JetBrainsMono Nerd Font`,
`Hanken Grotesk`, `Cormorant Garamond`, `Cinzel`; cursor
`Bibata-Modern-Classic` 24.

The GNOME accent of a Sanctuary theme is the GNOME accent nearest to the
pigment's OKLCH hue: cobalt and indigo blue, azure teal, verdure and viridian
green, gilt and amber yellow, ember orange, ruby red, rose and murrey pink,
amethyst purple.

## Templates

Templates are plain files where `{{key}}` becomes the palette value of any key
(`#89b4fa`, `JetBrainsMono Nerd Font`) and, for colors only, `{{key.raw}}` the
value without `#` (`89b4fa`), so formats such as `0x{{accent.raw}}ff` or
`rgb({{accent.raw}})` are written in the template. Any other `{{...}}` marker,
including `.raw` on a font or cursor key, fails the render.

- `templates/` holds the outputs every desktop shares; each one is listed
  with its consumer under [Rendered state](#rendered-state). A WM template
  directory cannot take the name of a shared output (`yazi`, `foot`, ...).
- The bat theme, the btop theme, the micro colorscheme and the Yazi flavor
  are adapted from the Catppuccin ports (MIT); Catppuccin's rosewater has no
  schema-2 role and renders as `hue_rose` (flamingo).
- A window manager layer stows its own templates into
  `~/.local/share/dotfiles/theme/templates/<wm>/`.

## Hooks

Layers may stow executables into two hook directories under
`~/.local/share/dotfiles/theme/`. Each hook receives the active directory in
`DOTFILES_THEME_DIR`, runs in name order, and never fails the engine: a
failing hook only warns, because the theme is already promoted.

| Directory | Runs | Used by |
|-----------|------|---------|
| `render.d/` | after `current` moves to another revision (`render`, a desktop apply, `DOTFILES_THEME`, `path`) and on every `set`; its stdout goes to stderr | the cli layer's `bat`, which rebuilds bat's cache |
| `reload.d/` | after `set` only, to reload a live session | `mangowm`, `bspwm` |

## Rendered state

```text
$XDG_STATE_HOME/dotfiles/theme/
├── selected                      # saved theme id
├── current -> <id>-<digest>      # promoted atomically
├── swatches/<id>.svg             # menu icons from `list --tsv`: accent disc on the background
└── <id>-<digest>/
    ├── gtk.css                   # @define-color overrides, imported by ~/.config/gtk-{3.0,4.0}/gtk.css
    ├── yazi/flavor.toml          # linked as ~/.config/yazi/flavors/theme.yazi; previews use the bat theme
    ├── alacritty/theme.toml      # [general] import of ~/.config/alacritty/alacritty.toml
    ├── foot/theme.ini            # include= of ~/.config/foot/foot.ini
    ├── bat/dotfiles.tmTheme      # linked as ~/.config/bat/themes/dotfiles.tmTheme
    ├── btop/dotfiles.theme       # linked as ~/.config/btop/themes/dotfiles.theme
    ├── micro/default.micro       # linked as ~/.config/micro/colorschemes/default.micro
    ├── lazygit/theme.yml         # appended to LG_CONFIG_FILE by zsh
    ├── fzf/options               # FZF_DEFAULT_OPTS_FILE set by zsh
    ├── background
    ├── metadata                  # schema=2, id, family, flavour, accent_name
    └── <wm>/...                  # one directory per installed WM
```

Every rendered file must be non-empty or the render fails. The terminals read
their file through the default state path
(`~/.local/state/dotfiles/theme/current/...`); zsh (`conf.d/10-environment.zsh`)
points lazygit and fzf at theirs; and after promoting a revision the engine
links the outputs an application only finds in its own config directory (Yazi,
bat, btop, micro), only when that directory exists and never over a real file.
Each application still starts when no theme was rendered yet:

| Application | Selects the theme | Without a rendered theme |
|-------------|-------------------|--------------------------|
| GTK 3/4 | `@import` in `~/.config/gtk-{3.0,4.0}/gtk.css` | skips the missing import: the GTK theme's own colors (Adwaita dark) |
| Yazi | `[flavor] dark = "theme"` in `theme.toml` | the `theme.yazi` flavor link only exists after the first render (the desktop layer renders on apply) |
| alacritty | `[general] import` | skips the missing import: default font and colors |
| foot | `include=` | reports the missing include and starts with its default font and colors |
| bat | `--theme="dotfiles"`, `BAT_THEME` | zsh sets `BAT_THEME=Catppuccin-mocha` (vendored) until bat's cache is not older than the rendered theme |
| btop | `color_theme = "dotfiles"` | falls back to its `Default` theme |
| micro | `"colorscheme": "default"` | the link shadows micro's builtin `default`, which stays when nothing is linked |
| lazygit | `LG_CONFIG_FILE` | zsh leaves it unset: lazygit's default colors |
| fzf | `FZF_DEFAULT_OPTS_FILE` | zsh leaves it unset: fzf's default colors |
| fastfetch | ANSI color names | follows the terminal palette (no rendered file) |

bat only sees a new palette after `bat cache --build`: the cli layer's
post-link builds it, and the bat render hook
(`~/.local/share/dotfiles/theme/render.d/bat`) rebuilds it whenever a revision
is promoted, so zsh never pins `Catppuccin-mocha` after a render-only path. It
exits 0 and reports a missing bat, and skips a cache outside `$HOME` (a render
into another target must not touch the running session's cache).

The terminal colors follow the ANSI roles; `16`/`17` are `hue_orange` and
`hue_rose`. MangoWM's `foot.ini` template repeats the shared `[colors-dark]`
block verbatim (foot only includes absolute paths, and MangoWM passes its own
rendered config), and `tests/theme-apps-smoke.sh` keeps the two identical.

The digest covers the palette, the engine and every template with its path, so
editing, adding or renaming a template renders a new revision. The `desktop`
layer renders on apply; `DOTFILES_THEME=<id>` overrides the saved selection for
one command.

## Commands

```text
dotfiles-theme list [--tsv] | current | set <id> | render [id] | validate [id] | path
dotfiles-theme menu <command> [args...]
```

`list` prints one theme id per line, sorted. `list --tsv` is the listing the
theme menus read: one line per theme, in the same order, with these
tab-separated columns:

| # | Column | Example |
|---|--------|---------|
| 1 | id | `sanctuary-compline-cobalt` |
| 2 | family | `sanctuary` |
| 3 | flavour | `compline` |
| 4 | accent name | `cobalt` |
| 5 | accent color | `#9bc1fb` |
| 6 | active (`1` for the selected theme, else `0`) | `0` |
| 7 | swatch icon path | `~/.local/state/dotfiles/theme/swatches/sanctuary-compline-cobalt.svg` |

The swatches are small SVGs (the accent as a disc with a foreground ring on the
background) written into the theme state, never into the repository; `list
--tsv` rewrites a swatch only when it is missing or no longer matches its
palette.

`menu` is the theme picker the WM menus share: family → flavour → accent,
each entry with its swatch and the active theme marked `(actual)` (also on its
family and flavour). For each level it runs `<command> [args...] <prompt>`
with one entry per line on stdin, `label<US>icon<TAB>value` (`US` is the 0x1f
unit separator, `icon` the swatch path), and reads the chosen value from its
stdout; a non-zero exit (Esc) goes back one level and leaves from the first. A
level with a single entry is skipped (Catppuccin has only Mocha), and the
chosen theme is applied with `set`. `mango-theme menu` passes its fuzzel
adapter (`mangowm_menu`).

`set` renders, runs every render hook, saves the selection, syncs the GNOME
accent color and cursor and runs every reload hook. `path` renders first when nothing is
active yet.
