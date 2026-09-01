# Cursor

Cursor usage and billing cycle in the Omarchy bar: included Cursor models, other API models, and the days left in the cycle.

## Install

```bash
omarchy plugin add https://github.com/sebday/omarchy-cursor.git --enable
```

## Requirements

- `curl`, `jq`, and `python3` (all ship with Omarchy)
- Cursor CLI or the Cursor IDE signed in on this machine

## Auth

Uses the session Cursor already stores on this machine:

1. Cursor CLI — `~/.config/cursor/auth.json`
2. Cursor IDE — `~/.config/Cursor/User/globalStorage/state.vscdb`

Sign in to either; no extra token setup.

## Settings

```bash
omarchy bar set evo.cursor refreshIntervalSec 300 --json
```

## IPC

```bash
omarchy-shell evo.cursor toggle
omarchy-shell evo.cursor refresh
omarchy-shell shell toggle evo.cursor
```

## License

MIT.
