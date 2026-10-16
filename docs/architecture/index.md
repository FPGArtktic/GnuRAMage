# Architecture overview

GnuRAMage is deliberately small: one Bash file, two generated helper scripts, and
`rsync` doing the actual work. This section documents the system as it exists in
**1.0.0**; planned changes are marked.

## System context

```mermaid
flowchart TB
    classDef person fill:#ede7f6,stroke:#5e35b1,stroke-width:2px,color:#1a1a1a
    classDef sys    fill:#fff8e1,stroke:#ffb300,stroke-width:2px,color:#1a1a1a
    classDef ext    fill:#eceff1,stroke:#546e7a,stroke-width:1.5px,color:#1a1a1a
    classDef store  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px,color:#1a1a1a

    OP["Operator<br/><i>starts, stops, reads logs</i>"]:::person
    CRON["cron / scheduler<br/><i>optional</i>"]:::ext
    APP["Workload<br/><i>reads and writes on the RAM disk</i>"]:::ext

    subgraph GR["GnuRAMage"]
        direction TB
        MAIN["gramage.sh"]:::sys
        INI["GnuRAMage.ini"]:::sys
        W1["gramage_copy_to_ram.sh"]:::sys
        W2["gramage_sync_to_disk.sh"]:::sys
    end

    RSYNC["rsync(1), cp(1), sync(1)"]:::ext
    HDD[("Persistent storage<br/>source_dir")]:::store
    RAM[("tmpfs / ramfs<br/>ramdisk_dir")]:::store
    LOG[("Log files")]:::store

    OP -- "CLI flags" --> MAIN
    OP -- "edits" --> INI
    INI -- "read" --> MAIN
    MAIN -- "generates" --> W1
    MAIN -- "generates" --> W2
    MAIN -- "executes" --> W1
    MAIN -- "executes" --> W2
    CRON -. "may call directly" .-> W2
    W1 -- "cp -a" --> RSYNC
    W2 -- "rsync -a --delete" --> RSYNC
    RSYNC -- "① copy" --> RAM
    RSYNC -- "② mirror back" --> HDD
    HDD -- "① read" --> RSYNC
    RAM -- "② read" --> RSYNC
    APP <--> RAM
    MAIN -- "append" --> LOG
```

## Component view

The script is organised into functional groups. There are no Bash modules; the
grouping is by naming convention and call pattern (see the
[function map](function-map.md)).

```mermaid
flowchart LR
    classDef c fill:#e3f2fd,stroke:#1565c0,stroke-width:1.5px,color:#1a1a1a
    classDef g fill:#fff8e1,stroke:#ffb300,stroke-width:1.5px,color:#1a1a1a

    subgraph GS["gramage.sh"]
        direction TB
        CLI["CLI parser<br/><code>parse_arguments</code><br/><code>print_usage</code>"]:::c
        CFG["Config reader<br/><code>parse_config_file</code><br/><code>check_directories</code>"]:::c
        LOGM["Logging<br/><code>log</code>, <code>log_*</code><br/><code>initialize_log_files</code>"]:::c
        GEN["Script generator<br/><code>generate_cp_script</code><br/><code>generate_rsync_script</code>"]:::c
        EXE["Executor<br/><code>execute_cp_script</code><br/><code>execute_rsync_script</code>"]:::c
        SCH["Scheduler<br/><code>run_sync_loop</code><br/><code>wait_for_key</code>"]:::c
        SIG["Shutdown<br/><code>cleanup</code> (trap)<br/><code>generate_report</code>"]:::c
    end
    W1["gramage_copy_to_ram.sh"]:::g
    W2["gramage_sync_to_disk.sh"]:::g

    CLI --> CFG --> GEN
    GEN -- "writes" --> W1
    GEN -- "writes" --> W2
    CFG --> SCH
    SCH --> EXE
    EXE -- "runs" --> W1
    EXE -- "runs" --> W2
    SCH -. "trap EXIT/INT/TERM" .-> SIG
    SIG --> EXE
    CLI & CFG & GEN & EXE & SCH & SIG -.-> LOGM
```

| Group | Responsibility | Globals written |
|-------|----------------|-----------------|
| CLI parser | Translate flags into globals; print usage. | `CONFIG_FILE`, `DRY_RUN`, `VERBOSE`, `LOGS_FILE`, `ERRORS_LOG_FILE`, `SCRIPT_GEN_ONLY`, `ONE_TIME_MODE` |
| Config reader | Locate and parse the INI; validate directories. | `SYNC_INTERVAL`, `LOG_LEVEL`, `VERIFY_CHECKSUMS`, `DEFAULT_SOURCE_DIR`, `DEFAULT_RAMDISK_DIR` |
| Logging | Level filter; console, log file, error file routing. | — |
| Script generator | Render two standalone Bash scripts with paths and excludes baked in. | files on disk |
| Executor | Run a worker script, capture status and stderr, update counters. | `TOTAL_FILES_COPIED`, `TOTAL_FILES_SYNCED` |
| Scheduler | Initial copy, then loop or one-shot. | `START_TIME`, `CLEANUP_NEEDED`, `TRAP_REGISTERED` |
| Shutdown | Final sync, `sync(1)`, report. | `CLEANUP_NEEDED` |

## Deployment view

```mermaid
flowchart TB
    classDef hw fill:#eceff1,stroke:#546e7a,stroke-width:2px,color:#1a1a1a
    classDef k  fill:#e0f7fa,stroke:#00838f,stroke-width:1.5px,color:#1a1a1a
    classDef u  fill:#fff8e1,stroke:#ffb300,stroke-width:1.5px,color:#1a1a1a

    subgraph HOST["GNU/Linux host"]
        direction TB
        subgraph USER["User space"]
            P["bash: gramage.sh<br/>(foreground, one per RAM dir)"]:::u
            R["rsync / cp child processes"]:::u
            A["Workload processes"]:::u
        end
        subgraph KERNEL["Kernel"]
            T["tmpfs mount<br/>/mnt/ramdisk"]:::k
            VFS["VFS / page cache"]:::k
            FS["ext4 / xfs / btrfs<br/>on block device"]:::k
        end
        subgraph HW["Hardware"]
            RAMHW["DRAM"]:::hw
            DISK["HDD / SSD"]:::hw
        end
    end
    P --> R
    R <--> T
    R <--> FS
    A <--> T
    T --- VFS
    FS --- VFS
    T --- RAMHW
    FS --- DISK
    P -- "sync(1) on exit" --> VFS
```

Properties that follow from this layout:

- The tmpfs content lives in **DRAM only**; a power loss or `umount` discards it.
  Everything written since the last sync-back is lost. The loss window equals
  `sync_interval` plus the duration of one rsync run.
- `rsync` and `cp` are ordinary user processes; throughput is bounded by the
  persistent device during sync-back and by memory bandwidth during the initial copy.
- `sync(1)` after the final rsync forces dirty pages to the block device, so a
  controlled stop is durable even if the host is powered off immediately afterwards.

## Design constraints

| Constraint | Consequence |
|------------|-------------|
| Single Bash file, no external libraries | Portability across distributions; no package manager required. |
| `rsync -a --delete` for sync-back | Exact mirror; deletions propagate; `--exclude` keeps junk on the RAM disk only. |
| RAM disk is authoritative after start | Edits made directly on persistent storage while running are **overwritten** on the next sync-back. |
| Worker scripts generated from config | Same behaviour available to cron without the main loop; paths and excludes cannot drift between the two runners. |
| Interactive wait (`read -t`) | Simple, but ties 1.0.0 to a TTY — replaced by a signal-driven wait in 1.1.0. |

## Planned 1.1.0 structural changes

```mermaid
flowchart LR
    classDef old fill:#fbe9e7,stroke:#d84315,color:#1a1a1a
    classDef new fill:#e8f5e9,stroke:#2e7d32,color:#1a1a1a
    O1["cp -a SRC* RAM<br/>no excludes, no dotfiles"]:::old --> N1["rsync -a --exclude… SRC/ RAM/<br/>shared exclude array"]:::new
    O2["read -t N -n 1"]:::old --> N2["sleep N & wait<br/>trap INT TERM USR1"]:::new
    O3["grep | cut | tr INI parser"]:::old --> N3["line-based parser<br/>sections, exact keys, arrays"]:::new
    O4["echo WARNING on empty RAM"]:::old --> N4["abort: empty / no sentinel /<br/>not tmpfs (require_ramfs)"]:::new
    O5["/tmp/rsync_error.log"]:::old --> N5["mktemp + flock lock"]:::new
```

Details: [Known issues](../development/known-issues.md) and
[Roadmap](../development/roadmap.md).
