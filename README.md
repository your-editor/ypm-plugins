# ypm-plugins

**Version: v1700**

The YED Package Manager plugin collection. Each plugin lives as a git
submodule under `ypm_plugins/`, and every plugin's manpage is copied into
`man/man7/` so it can be browsed without initializing the submodules.

Branches track yed versions:

- `v1600` — compatible with yed `master`
- `v1700` — compatible with yed `dev`

## Scripts

All scripts live at the repo root and are meant to be run from there.

### Plugin management

- **`add_plugin.sh`** — Add a new plugin. Prompts for a repo URL and
  target path, runs `git submodule add`, and copies any `.7` files from
  the plugin root into `man/man7/`.

- **`update_plugin.sh [path]`** — Update an existing plugin. Inits/updates
  the submodule, checks out `main` (falling back to `master`), pulls, and
  refreshes the plugin's manpages in `man/man7/`. Prompts for a path if
  none is given.

- **`remove_plugin.sh [path]`** — Remove a plugin. Deinits the submodule,
  runs `git rm`, clears `.git/modules/<path>`, and deletes the plugin's
  manpages from `man/man7/`. Shows a preview and asks for confirmation
  before doing anything destructive.

### Build verification

- **`build_check.sh [branch]`** — Build-test every plugin against a yed
  version. Clones and builds yed into `.build_check/yed`, checks out the
  matching `ypm-plugins` branch, inits all submodules, and attempts to
  build each plugin. Prints a colored pass/fail/skip summary at the end.

  Branch mapping:
  - `master` → ypm-plugins `v1600`
  - `dev` → ypm-plugins `v1700` (default)

- **`build_clean.sh`** — Clean up after `build_check.sh`. Removes the
  `.build_check/` workspace, deletes any `.so` files from plugin
  directories, and deinits all submodules.

### Manpage verification

- **`manpage_check.sh`** — Verify that `man/man7/` is in sync with every
  plugin's source `.7` files. Auto-inits submodules if needed, then
  reports for every plugin whether its manpage is **up to date**,
  **outdated**, **missing**, or absent. Also flags **orphaned** files in
  `man/man7/` that no plugin claims (a short whitelist covers entries
  like `ypm.7` that intentionally have no plugin source).

  Exits non-zero if anything is outdated or missing, so it can be used
  in CI.
