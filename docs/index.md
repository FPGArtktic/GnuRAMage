---
title: Home
---

<p align="center">
  <img src="logo.png" alt="GnuRAMage logo" width="200">
</p>

# GnuRAMage

**RAM disk mirroring with periodic `rsync` write-back, in a single Bash script.**

[![CI](https://github.com/FPGArtktic/GnuRAMage/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/FPGArtktic/GnuRAMage/actions/workflows/ci.yml)
[![Docs](https://readthedocs.org/projects/gnuramage/badge/?version=latest)](https://gnuramage.readthedocs.io/en/latest/)
[![Release](https://img.shields.io/github/v/tag/FPGArtktic/GnuRAMage?sort=semver&label=release&color=blue)](https://github.com/FPGArtktic/GnuRAMage/releases)
[![License](https://img.shields.io/github/license/FPGArtktic/GnuRAMage?color=blue)](https://github.com/FPGArtktic/GnuRAMage/blob/master/LICENSE)

GnuRAMage copies a directory tree from persistent storage to a RAM disk, keeps the
persistent copy current with periodic `rsync --delete`, and performs a final sync on
exit. It targets hosts with large tmpfs/ramfs mounts where a workload needs RAM-speed
I/O but a power loss must not cost work.

```mermaid
flowchart LR
    classDef disk fill:#e8eaf6,stroke:#5e35b1,stroke-width:2px,color:#1a1a1a
    classDef ram  fill:#fff8e1,stroke:#ffb300,stroke-width:2px,color:#1a1a1a
    HDD[("Persistent storage<br/><code>source_dir</code>")]:::disk
    RAM[("RAM disk<br/><code>ramdisk_dir</code>")]:::ram
    HDD -- "① initial copy" --> RAM
    RAM -- "② every <code>sync_interval</code>" --> HDD
    RAM -- "③ final sync on exit" --> HDD
```

<div class="grid cards" markdown>

-   :material-rocket-launch:{ .lg .middle } **Getting started**

    ---

    Install, mount a tmpfs, write a 10-line INI file, run.

    [:octicons-arrow-right-24: Guide](guide/getting-started.md)

-   :material-sitemap:{ .lg .middle } **Architecture**

    ---

    Component, deployment, sequence, activity and state diagrams of the script.

    [:octicons-arrow-right-24: Architecture](architecture/index.md)

-   :material-shield-alert:{ .lg .middle } **Data safety model**

    ---

    Which copy is the source of truth, what `--delete` means, and the guards.

    [:octicons-arrow-right-24: Data safety](architecture/data-safety.md)

-   :material-bug:{ .lg .middle } **Known issues & roadmap**

    ---

    Verified defects in 1.0.0 and the 1.1.0 plan.

    [:octicons-arrow-right-24: Known issues](development/known-issues.md)

</div>

## At a glance

| | |
|---|---|
| Language | Bash ≥ 4.0, single file (`gramage.sh`) |
| Dependencies | `rsync` ≥ 3.1, coreutils, findutils |
| Configuration | INI file (`[SETTINGS]`, `[DIRECTORIES]`, `[EXCLUDE]`) |
| Modes | continuous loop, `--one-time`, `--dry-run`, `--script-gen-only` |
| License | GPL-3.0-or-later |
| Source | [github.com/FPGArtktic/GnuRAMage](https://github.com/FPGArtktic/GnuRAMage) |

!!! warning "Source of truth"
    After the initial copy the **RAM disk is authoritative**. The sync-back runs
    `rsync -a --delete RAM/ → source/`. Read the
    [data safety model](architecture/data-safety.md) before using it on data you
    care about, and note the [known issues](development/known-issues.md) of 1.0.0.
