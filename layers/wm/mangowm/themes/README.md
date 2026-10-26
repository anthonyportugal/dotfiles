# Theme contract

Theme sources are versioned data. They are not executable and must never be
sourced by a shell. `mango-theme` parses a strict `key=value` schema, validates
every field and writes application-specific artifacts under XDG state.

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
├── current -> <theme-id>-<content-hash>
└── <theme-id>-<content-hash>/
    ├── background
    ├── foot.ini
    ├── fuzzel.ini
    ├── mako.conf
    ├── mango.conf
    ├── metadata
    ├── swaylock.conf
    ├── waybar.css
    ├── wlogout.css
    └── xdg-config/satty/config.toml
```

Generation uses a temporary sibling followed by an atomic directory rename and
an atomic `current` symlink replacement. Re-running an unchanged renderer
reuses the same immutable revision. No renderer writes back into `themes/` or
another tracked path.

```bash
mango-theme validate
mango-theme render
mango-theme path
```
