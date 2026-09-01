# Cursor

Cursor usage and billing cycle in the Omarchy bar: included Cursor models, other API models, and the days left in the cycle.

Signed-in Cursor is enough. The widget reads the session Cursor already stored — no extra token to copy.

## Install

A plugin is a git repo with a `manifest.json` at its root. Adding one clones it into `~/.config/omarchy/plugins/evo.cursor/`.

```bash
omarchy plugin add https://github.com/sebday/omarchy-plugin-cursor.git --enable
```

A local path works the same way. Plugins run as unsandboxed code inside `omarchy-shell`. Review the files before enabling.

## Requirements

- `curl`, `jq`, and `python3` (all ship with Omarchy)
- Cursor CLI or the Cursor IDE signed in on this machine

## Auth

The bar process does not see tokens exported from your interactive shell. Resolution order:

1. `CURSOR_ACCESS_TOKEN` if the Omarchy session already has it (Hyprland env or `~/.config/environment.d/`)
2. Cursor CLI `~/.config/cursor/auth.json`
3. Cursor IDE `~/.config/Cursor/User/globalStorage/state.vscdb`
4. `pass` at `omarchy/cursor/token`, then `evoshell/cursor/access-token`

```bash
# Optional session override for the bar
echo 'CURSOR_ACCESS_TOKEN=your-jwt' > ~/.config/environment.d/cursor.conf

# Optional pass fallback
pass insert omarchy/cursor/token
```

## Bar

| Click | Action |
|---|---|
| Left | Toggle the usage panel |
| Middle | Open the Cursor spending dashboard |
| Right | Refresh usage |

## Panel

Left-click the bar icon for included vs other-model gauges, tokens this cycle and today, days left, and a model breakdown. Auth problems show how to sign in, with a link to the spending page.

## Settings

```bash
omarchy bar set evo.cursor refreshIntervalSec 300 --json
```

| Key | Default | What it does |
|---|---|---|
| `refreshIntervalSec` | `300` | How often usage is refetched |

## IPC

```bash
omarchy-shell evo.cursor toggle
omarchy-shell evo.cursor refresh
omarchy-shell shell toggle evo.cursor
```

| Call | Action |
|---|---|
| `open` / `show` | Open the panel |
| `close` / `hide` | Close the panel |
| `toggle` | Toggle the panel |
| `refresh` | Refresh usage |

## License

MIT.
