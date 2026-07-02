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
  target path, runs `git submodule add`, and copies **every** `.7` file
  from the plugin root into `man/man7/` (matched by glob, so full-path
  names like `lang-syntax-yaml.7` are handled correctly).

- **`update_plugin.sh [path]`** — Update an existing plugin. Inits/updates
  the submodule, checks out `main` (falling back to `master`), pulls, and
  refreshes **all** of the plugin's manpages in `man/man7/`. Prompts for a
  path if none is given.

- **`remove_plugin.sh [path]`** — Remove a plugin. Deinits the submodule,
  runs `git rm`, clears `.git/modules/<path>`, and deletes the plugin's
  manpages from `man/man7/`. Shows a preview and asks for confirmation
  before doing anything destructive.

### Build verification

- **`build_check.sh [branch]`** — Build-test every plugin against a yed
  version. Clones and builds yed into a throwaway `.build_check/`
  workspace, checks out the matching `ypm-plugins` branch, and attempts to
  build each plugin. Prints a colored pass/fail/skip summary at the end.

  It initializes **only** submodules that aren't populated yet; any
  submodule already checked out is tested exactly as it sits on disk. It
  never runs a bare `git submodule update`, so it will not reset a plugin
  to the recorded commit or revert local work.

  Branch mapping (run the branch that matches the one you're on):
  - `master` → ypm-plugins `v1600`
  - `dev` → ypm-plugins `v1700` (default)

- **`build_clean.sh`** — Clean up after `build_check.sh`. Removes the
  `.build_check/` workspace and deletes build artifacts (`.so`) left in the
  plugin directories. It does **not** touch git state — no `submodule
  deinit`, no `git checkout` — so uncommitted changes are safe.

### Manpage verification

- **`manpage_check.sh`** — Verify that `man/man7/` is in sync with every
  plugin's source `.7` files. Initializes **only** missing submodules
  (never resets populated ones), then byte-compares each plugin's `.7`
  against its `man/man7/` copy and reports whether the manpage is **up to
  date**, **outdated**, **missing**, or absent. The comparison reflects the
  plugin's currently checked-out commit. Also flags **orphaned** files in
  `man/man7/` that no plugin claims (a short whitelist covers entries
  like `ypm.7` that intentionally have no plugin source).

  Exits non-zero if anything is outdated or missing, so it can be used
  in CI.

## Typical workflow

The scripts split into two roles: **plugin management** changes tracked
state, while **verification** only reads it (and cleanup only removes build
artifacts). Because verification and cleanup never touch git state, you can
validate before *or* after committing.

```
1. Add / update / remove plugins:
     ./add_plugin.sh   |   ./update_plugin.sh <path>   |   ./remove_plugin.sh <path>

2. Validate:
     ./build_check.sh dev      # every plugin compiles against the right yed
     ./manpage_check.sh        # man/man7/ copies are current

3. Clean the build sandbox:
     ./build_clean.sh

4. Commit and push the parent repo (submodule pointers, .gitmodules,
   and the man/man7/ changes).
```

Steps 2 and 3 observe whatever is currently checked out and leave it alone,
so running them either before or after the commit in step 4 is safe.
