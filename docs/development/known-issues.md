# Known issues in 1.0.0

All items below were reproduced on 2026-10-16 with rsync 3.2.7 and Bash 5.2.
IDs are stable and referenced from commits and tests.

Severity: **S1** data loss or unusable as a daemon · **S2** wrong behaviour ·
**S3** hygiene.

## Summary

```mermaid
quadrantChart
    title Impact vs. fix effort
    x-axis Low effort --> High effort
    y-axis Low impact --> High impact
    quadrant-1 Fix first
    quadrant-2 Plan carefully
    quadrant-3 Opportunistic
    quadrant-4 Worth it
    A non-TTY busy loop: [0.25, 0.85]
    B delete on empty RAM: [0.45, 0.95]
    C nested copy: [0.35, 0.80]
    D SIGTERM ignored: [0.30, 0.75]
    E INI parser: [0.60, 0.60]
    F cp glob / no excludes: [0.40, 0.55]
    G checksums unused: [0.10, 0.30]
    H fixed tmp path: [0.15, 0.25]
    I no lock: [0.20, 0.45]
    J shellcheck: [0.30, 0.15]
```

## Details

### A — Busy loop without a TTY  `S1`

`wait_for_key` uses `read -t "$interval" -n 1`. When stdin is not a terminal
(`< /dev/null`, `nohup`, systemd) `read` returns immediately with EOF, which the
function interprets as a timeout; the sync-back runs back-to-back.

```bash
timeout -s KILL 3 ./gramage.sh --config test/gramage_test.ini < /dev/null \
  | grep -c 'Executing rsync'       # → 41   (expected: 0)
```

**Fix:** `sleep "$SYNC_INTERVAL" & wait $!` (interruptible by signals); keep the
key-press shortcut only when `[ -t 0 ]`.

### B — `--delete` from an empty RAM directory wipes the source  `S1`

`gramage_sync_to_disk.sh` prints `[WARNING] RAM disk directory is empty!` and then
runs `rsync -a --delete RAM/ SRC/` anyway.

```bash
# populated fixture: 25 files on the "disk"
rm -rf /tmp/ram_disk_test_ramdisk && mkdir /tmp/ram_disk_test_ramdisk
./gramage_sync_to_disk.sh
find /tmp/ram_disk_test_source -type f | wc -l   # → 4
```

**Fix:** abort before sync-back when the RAM directory is empty, lacks the sentinel
written by the initial copy, or (with `require_ramfs = true`) is not on
tmpfs/ramfs. See [Data safety model](../architecture/data-safety.md).

### C — Nested copies when `source_dir` has no trailing slash  `S1`

The initial copy is `cp -a "$source_dir"* "$ramdisk_dir"`. Without a trailing slash
the glob matches the directory itself, which is copied *into* the RAM dir; the next
sync-back mirrors it back one level deeper, and so on. The shipped
`test/gramage_test.ini` triggers it; the test suite does not notice.

```bash
./gramage.sh --config test/gramage_test.ini --one-time   # × 3
find /tmp/ram_disk_test_source -type d -name ram_disk_test_source
# /tmp/ram_disk_test_source/ram_disk_test_source/ram_disk_test_source/ram_disk_test_source
```

**Fix:** normalise both paths once (`realpath -m`, strip trailing `/`) and always
pass `"$dir/"` to rsync; drop the `cp` glob (see F).

### D — SIGTERM / SIGINT do not terminate the process  `S1`

`trap cleanup EXIT INT TERM`: the handler runs the final sync and report, then
returns; Bash resumes the `while true` loop. `CLEANUP_NEEDED` is now `false`, so a
later exit performs no final sync at all.

```bash
./gramage.sh --config test/gramage_test.ini &  pid=$!
sleep 1; kill -TERM $pid; sleep 3
kill -0 $pid && echo "still alive"          # → still alive
```

**Fix:** INT/TERM handlers set a stop flag and kill the `sleep` child; the loop
exits; `cleanup` runs once from the `EXIT` trap; `exit 0`. Also avoid the second
final sync in `--one-time`.

### E — INI parser drops or mangles values  `S2`

- The `[EXCLUDE]` reader filters comment text with
  `grep -v -i 'pattern\|exclude\|synchronization\|line\|format'` — any pattern
  containing those words is silently removed.
- Patterns are iterated with `for p in $exclude_patterns` → split on spaces.
- Keys are matched by prefix (`^sync_interval`), values pass through `tr -d ' '` →
  paths with spaces are corrupted.

```ini
[EXCLUDE]
*.bak
baseline/
*.format
my pattern.txt
```
→ generated script contains only `--exclude='*.bak'`.

**Fix:** line-based parser (`while IFS= read -r`), section tracking, split on the
first `=`, trim via parameter expansion, exact key match, excludes in a Bash array,
comments only when the line starts with `#` or `;`.

### F — Initial copy ignores excludes and top-level dotfiles  `S2`

`cp -a "$source_dir"*` does not match dotfiles, fails on an empty source, hides
errors with `2>/dev/null`, and applies no `--exclude`. A meaningless
`.rsyncignore` is touched on the RAM disk as a success marker.

**Fix:** `rsync -a --exclude… "$SRC/" "$RAM/"` using the same exclude array as the
sync-back.

### G — `verify_checksums` has no effect  `S2`

Parsed into `VERIFY_CHECKSUMS`, never read (ShellCheck SC2034).

**Fix:** append `--checksum` to the rsync argument array when true; document the cost.

### H — Fixed temporary file `/tmp/rsync_error.log`  `S3`

Collides between concurrent instances and users; symlink attack surface in a
shared `/tmp`.

**Fix:** `mktemp` with trap-based removal, or capture stderr into a variable.

### I — No instance lock  `S3`

Two instances on the same configuration interleave `--delete` runs.

**Fix:** `flock -n` on a lock file derived from the normalised `ramdisk_dir` under
`${XDG_RUNTIME_DIR:-/tmp}`; exit 2 with a clear message.

### J — ShellCheck findings  `S3`

`shellcheck -S warning gramage.sh test/*.sh` reports SC2155, SC2034, SC2119/2120,
SC2162, SC2016, SC2181, SC2086, SC2207. The CI lint job stays red until they are
fixed; the fixes are mechanical and behaviour-neutral.

## Minor

- `--help` claims `--logs` accepts JSON; not implemented.
- `TOTAL_FILES_SYNCED` counts cycles, not files.
- Worker scripts are written into the script directory → fails on a read-only
  install location.
- `check_directories` creates `ramdisk_dir` even when no tmpfs is mounted there.
- Repository `GnuRAMage.ini` ships `sync_interval = 10` and placeholder paths.
- `test/gnuramage_test.ini` duplicates `test/gramage_test.ini`.
