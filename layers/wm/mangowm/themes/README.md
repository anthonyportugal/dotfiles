# Theme contract

Theme sources are versioned data. They are not executable and must never be
sourced by a shell. The future renderer will parse a strict `key=value` schema,
validate every field and write application-specific artifacts under XDG state.

## Schema 1

A palette must contain:

- `schema`, `id`, `family`, `flavour` and `accent_name` metadata;
- the 26 Catppuccin palette colors as lowercase `#rrggbb` values;
- resolved semantic roles used by adapters.

IDs use lowercase ASCII letters, digits and hyphens. Keys may appear only once;
unknown or missing keys are errors. Values do not interpolate other keys so the
same file can be parsed without executing code.

The default is `catppuccin-mocha-pink`. Adding a future theme requires a new
directory with the same schema; existing app configs must consume semantic
roles rather than a flavor-specific name.

Generated files and the active selection will live below:

```text
$XDG_STATE_HOME/mangowm/theme/
├── active
└── <theme-id>/
    ├── foot.ini
    ├── fuzzel.ini
    ├── mako.conf
    ├── satty.toml
    ├── swaylock.conf
    ├── waybar.css
    └── wlogout.css
```

Generation must use a temporary sibling directory followed by an atomic rename.
No renderer may write back into `themes/` or another tracked path.
