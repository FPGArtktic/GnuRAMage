# Getting started

## Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| GNU/Linux | any current distribution | tested in CI on Ubuntu, Debian bookworm, Arch |
| Bash | ≥ 4.0 | `bash --version` |
| rsync | ≥ 3.1 | `rsync --version` |
| coreutils, findutils | standard | `cp`, `find`, `sync`, `date` |
| A RAM disk | tmpfs or ramfs mount | see below |

## Install

=== "git clone"

    ```bash
    git clone https://github.com/FPGArtktic/GnuRAMage.git
    cd GnuRAMage
    chmod +x gramage.sh
    ```

=== "Direct download"

    ```bash
    mkdir -p ~/opt/gnuramage && cd ~/opt/gnuramage
    curl -fsSLO https://raw.githubusercontent.com/FPGArtktic/GnuRAMage/master/gramage.sh
    curl -fsSLO https://raw.githubusercontent.com/FPGArtktic/GnuRAMage/master/GnuRAMage.ini
    chmod +x gramage.sh
    ```

=== "Release asset"

    Download `gramage.sh`, `GnuRAMage.ini` and `SHA256SUMS` from the
    [Releases page](https://github.com/FPGArtktic/GnuRAMage/releases) and verify:

    ```bash
    sha256sum -c SHA256SUMS
    ```

!!! note "Writable location"
    The script writes two generated worker scripts next to itself
    (`gramage_copy_to_ram.sh`, `gramage_sync_to_disk.sh`). Keep it in a directory
    you can write to; do not install it into `/usr/bin`.

## Mount a RAM disk

```bash
# One-off (lost on reboot)
sudo mkdir -p /mnt/ramdisk
sudo mount -t tmpfs -o size=64G,mode=0755 tmpfs /mnt/ramdisk

# Persistent — /etc/fstab
tmpfs  /mnt/ramdisk  tmpfs  size=64G,mode=0755  0  0
```

Check that it is really tmpfs before trusting it:

```bash
findmnt -no FSTYPE --target /mnt/ramdisk     # → tmpfs
```

## Configure

Edit `GnuRAMage.ini`:

```ini
[SETTINGS]
sync_interval = 180
log_level = INFO
verify_checksums = false

[DIRECTORIES]
source_dir = /srv/data/
ramdisk_dir = /mnt/ramdisk/data

[EXCLUDE]
*.tmp
*.bak
cache/
```

!!! tip "Trailing slash on `source_dir` (1.0.0)"
    In 1.0.0 the initial copy expands `source_dir*`. Without a trailing slash the
    directory itself is copied *into* the RAM disk and nests deeper on every cycle.
    Always write `source_dir = /srv/data/`. Path normalisation is planned for 1.1.0
    ([known issue C](../development/known-issues.md)).

Full reference: [Configuration](configuration.md).

## Run

```bash
./gramage.sh --dry-run --verbose              # preview, no changes
./gramage.sh --one-time --verbose             # copy, one sync-back, exit
./gramage.sh --logs run.log --errors-log err.log   # continuous mode
```

Stop the continuous mode with ++ctrl+c++ — a final sync runs before the process
exits. See [Operations](operations.md) for the full lifecycle.
