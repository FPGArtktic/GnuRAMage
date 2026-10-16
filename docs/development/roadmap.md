# Roadmap

Phases are ordered; each is one or more pull requests. Dates are intentionally
absent — the project is maintained in spare time.

```mermaid
timeline
    title GnuRAMage releases
    2025-05 : 1.0.0 — initial release
            : INI config, cp → RAM, rsync --delete back, worker scripts, custom tests
    Phase 0 : CI green
            : ShellCheck clean, 3-distro test matrix, docs build
    Phase 1 : 1.1.0 — correctness and data safety
            : sync-back guard, signal-driven loop, path normalisation
            : rsync in both directions, INI parser rewrite, flock, mktemp
    Phase 2 : 1.1.0 — ergonomics
            : --version, --sync-now, SIGUSR1, systemd unit, bats suite
    Phase 3 : 1.2.0 — features (to be discussed)
            : inotify real-time mode, snapshots before --delete, multiple directory pairs
```

## Phase 0 — CI green

- [x] Fix all ShellCheck findings (issue J) without behaviour change.
- [x] Generated sync script honours `--verbose` / `--dry-run` (issue K).
- [ ] Confirm `ci.yml` passes on Ubuntu, Debian and Arch.
- [ ] Docs build with `mkdocs build --strict`.

## Phase 1 — correctness and data safety → 1.1.0

Order matters: the parser rewrite comes first because every later fix reads
configuration through it; `set -euo pipefail` comes last because it changes the
meaning of every unchecked command.

```mermaid
gantt
    title Phase 1 dependency order (relative — days are units, not dates)
    dateFormat YYYY-MM-DD
    axisFormat %d
    section Parser
    E  INI parser rewrite             :e, 2026-01-01, 2d
    section Paths and copy
    C  path normalisation             :c, after e, 1d
    F  rsync for initial copy         :f, after c, 1d
    section Guard
    B  empty / sentinel / tmpfs guard :b, after f, 2d
    section Signals
    A  interruptible wait             :a, after e, 1d
    D  INT and TERM handlers          :d, after a, 1d
    section Hygiene
    G  checksum flag                  :g, after f, 1d
    H  mktemp                         :h, after d, 1d
    I  flock                          :i, after h, 1d
    section Finish
    set -euo pipefail                 :s, after b, 1d
    VERSION constant and --version    :v, after s, 1d
```

- [ ] **E** line-based INI parser; fixture with spaces, comments, duplicate keys,
      the five "forbidden" words.
- [ ] **C** `realpath -m` normalisation; always `dir/` to rsync.
- [ ] **F** initial copy via rsync with the shared exclude array; dotfiles included;
      remove the `.rsyncignore` marker.
- [ ] **B** refuse sync-back on empty RAM dir / missing sentinel / not tmpfs
      (`require_ramfs`, default `true`).
- [ ] **A** `sleep & wait` loop; key-press shortcut only on a TTY.
- [ ] **D** INT/TERM set a flag and kill `sleep`; single `cleanup` on EXIT; `exit 0`.
- [ ] **G** `--checksum` when `verify_checksums = true`.
- [ ] **H** `mktemp` for rsync stderr.
- [ ] **I** `flock` instance lock, exit 2.
- [ ] `set -euo pipefail` after all `$?` checks are rewritten.
- [ ] `VERSION="1.1.0"` and `--version`.

## Phase 2 — ergonomics → 1.1.0

- [ ] `--sync-now`; `SIGUSR1` → immediate sync-back inside the loop.
- [ ] `contrib/gnuramage.service` (`Type=simple`, `TimeoutStopSec` ≥ rsync duration,
      `Restart=on-failure`); documented in Operations.
- [ ] Config lookup: `--config` → `$XDG_CONFIG_HOME/gnuramage/config.ini` →
      `/etc/gnuramage/config.ini` → script directory.
- [ ] `--json` log output (NDJSON) or drop the claim from `--help`.
- [ ] bats-core suite with the regression matrix from [Testing](testing.md).
- [ ] Decide the fate of worker-script generation (keep as export feature from the
      same argument array, or remove and bump to 2.0.0).

## Phase 3 — features → 1.2.0 (needs a design discussion first)

- [ ] Real-time mode: `inotifywait -m -r` with debounce instead of a fixed interval.
- [ ] Snapshot before each `--delete` sync (`--backup --backup-dir` or
      `--link-dest`) with retention.
- [ ] Several `[DIRECTORIES]` pairs per configuration.

## Non-goals

- Rewrite in another language — single-file Bash is the point.
- Bidirectional synchronisation — the RAM disk is authoritative by design.
- Network targets — use rsync directly for that.
