# dotfiles

Install (or re-run any time to update — idempotent):

```bash
curl -fsSL https://raw.githubusercontent.com/AntonOresten/dotfiles/main/bootstrap.sh | bash
```

Or with git:

```bash
git clone https://github.com/AntonOresten/dotfiles ~/dotfiles 2>/dev/null; ~/dotfiles/bootstrap.sh
```

`bootstrap.sh` clones the repo (default `~/dotfiles`, override with `DOTFILES_DIR`)
or fast-forwards an existing checkout, then runs `install.sh`.

## Auto-sync

Each interactive shell checks the repo via `sync.sh`:

- A throttled background `git fetch` (default once per 24h).
- If a previous fetch left the checkout behind upstream, it fast-forwards
  locally and re-runs `install.sh`, printing a one-line notice.
- Skipped if the working tree is dirty, so local edits are never clobbered.

Tunables:

- `DOTFILES_NO_SYNC=1` — disable auto-sync entirely.
- `DOTFILES_SYNC_INTERVAL=<seconds>` — fetch throttle (default `86400`).
