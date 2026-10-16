# Runtime behaviour

Sequence, activity and state views of one run of `gramage.sh` (1.0.0 semantics).

## Start-up sequence

```mermaid
sequenceDiagram
    autonumber
    actor OP as Operator
    participant M as gramage.sh
    participant INI as GnuRAMage.ini
    participant FS as Filesystem
    participant W1 as gramage_copy_to_ram.sh
    participant W2 as gramage_sync_to_disk.sh

    OP->>M: ./gramage.sh [flags]
    M->>M: parse_arguments
    M->>M: check_rsync (command -v rsync)
    alt rsync missing
        M-->>OP: [ERROR] rsync is not installed
        M-->>OP: exit 1
    end
    M->>INI: locate (CWD, then script dir)
    M->>INI: grep [SETTINGS] / [DIRECTORIES] / [EXCLUDE]
    INI-->>M: sync_interval, log_level, verify_checksums, source_dir, ramdisk_dir, patterns
    M->>FS: test -d source_dir
    alt source_dir missing
        M-->>OP: [ERROR] Source directory does not exist
        M-->>OP: exit 1
    end
    M->>FS: mkdir -p ramdisk_dir (skipped in --dry-run)
    M->>W2: write script (paths + --exclude lines baked in), chmod +x
    M->>W1: write script, chmod +x
    M->>FS: touch --logs / --errors-log files
    opt --script-gen-only
        M-->>OP: Scripts generated. Exiting.
    end
    M->>M: run_sync_loop
```

## Sync cycle sequence

```mermaid
sequenceDiagram
    autonumber
    participant M as gramage.sh
    participant W2 as gramage_sync_to_disk.sh
    participant R as rsync
    participant RAM as ramdisk_dir
    participant HDD as source_dir
    participant L as log / errors-log

    loop every sync_interval seconds
        M->>M: wait_for_key(sync_interval)
        M->>L: [INFO] Executing rsync to hard disk script
        M->>W2: exec (stderr → /tmp/rsync_error.log)
        W2->>RAM: test -d, ls -A
        Note over W2,RAM: empty RAM dir only prints a WARNING<br/>and continues (1.0.0)
        W2->>HDD: mkdir -p
        W2->>R: rsync -a [-v] --exclude=… --delete RAM/ HDD/
        R->>RAM: read tree
        R->>HDD: create / update / delete
        R-->>W2: exit status
        alt status ≠ 0
            W2-->>M: non-zero
            M->>L: [ERROR] Failed to sync… + captured stderr
        else status = 0
            W2-->>M: 0
            M->>L: [INFO] Files synced to hard disk successfully
            M->>M: TOTAL_FILES_SYNCED += 1
        end
    end
```

## Shutdown sequence

```mermaid
sequenceDiagram
    autonumber
    actor OP as Operator
    participant SH as bash signal layer
    participant M as gramage.sh
    participant W2 as gramage_sync_to_disk.sh
    participant K as kernel

    OP->>SH: Ctrl+C (SIGINT) or key press
    SH->>M: trap → cleanup
    M->>M: CLEANUP_NEEDED? yes
    M->>W2: execute_rsync_script (final)
    W2-->>M: status
    M->>K: sync (twice)
    M->>M: generate_report
    M->>M: CLEANUP_NEEDED = false
    Note over SH,M: 1.0.0: after the INT/TERM trap returns, control goes back<br/>to the loop — the process exits only via a key press path or SIGKILL.<br/>1.1.0: handler sets a flag, loop exits, EXIT trap runs cleanup once.
```

## Activity diagram — main loop

```mermaid
flowchart TD
    classDef act  fill:#e3f2fd,stroke:#1565c0,color:#1a1a1a
    classDef dec  fill:#fff8e1,stroke:#ffb300,color:#1a1a1a
    classDef term fill:#fbe9e7,stroke:#d84315,color:#1a1a1a
    classDef ok   fill:#e8f5e9,stroke:#2e7d32,color:#1a1a1a

    A([run_sync_loop]) --> B[register trap cleanup EXIT INT TERM<br/>CLEANUP_NEEDED = true<br/>START_TIME = now]:::act
    B --> C[execute_cp_script]:::act
    C --> D{copy ok?}:::dec
    D -- no --> E[log ERROR Initial copy failed]:::act --> X1([exit 1]):::term
    D -- yes --> F{ONE_TIME_MODE?}:::dec
    F -- yes --> G[execute_rsync_script]:::act --> X0([exit 0 → EXIT trap → cleanup]):::ok
    F -- no --> H[log Starting synchronization loop]:::act
    H --> I[wait_for_key SYNC_INTERVAL]:::act
    I --> J{read returned<br/>before timeout?}:::dec
    J -- "key pressed" --> K[break]:::act
    J -- "timeout<br/>(or stdin EOF — issue A)" --> L[execute_rsync_script]:::act --> I
    K --> M[execute_rsync_script]:::act --> N[sync; sync]:::act --> O([return → main ends → EXIT trap → cleanup]):::ok
```

!!! note "Double final sync"
    On a key press the loop performs a sync-back (`M`), then `cleanup` on `EXIT`
    performs another one. Harmless (rsync is idempotent) but slow on large trees;
    collapsed into one in 1.1.0.

## Activity diagram — `execute_rsync_script`

```mermaid
flowchart TD
    classDef act  fill:#e3f2fd,stroke:#1565c0,color:#1a1a1a
    classDef dec  fill:#fff8e1,stroke:#ffb300,color:#1a1a1a
    classDef term fill:#fbe9e7,stroke:#d84315,color:#1a1a1a
    classDef ok   fill:#e8f5e9,stroke:#2e7d32,color:#1a1a1a

    S([execute_rsync_script]) --> A[log INFO Executing rsync]:::act
    A --> B{DRY_RUN?}:::dec
    B -- yes --> C[log Dry run: would execute]:::act --> R0([return 0]):::ok
    B -- no --> D{VERBOSE?}:::dec
    D -- yes --> E["run W2 --verbose<br/>2> /tmp/rsync_error.log"]:::act
    D -- no --> F["run W2 > /dev/null<br/>2> /tmp/rsync_error.log"]:::act
    E --> G{status = 0?}:::dec
    F --> G
    G -- no --> H[log ERROR code + stderr<br/>append to errors-log<br/>rm tmp file]:::act --> R1([return 1]):::term
    G -- yes --> I[log INFO synced<br/>TOTAL_FILES_SYNCED++<br/>rm tmp file]:::act --> R0
```

## Activity diagram — generated `gramage_sync_to_disk.sh`

```mermaid
flowchart TD
    classDef act  fill:#e3f2fd,stroke:#1565c0,color:#1a1a1a
    classDef dec  fill:#fff8e1,stroke:#ffb300,color:#1a1a1a
    classDef term fill:#fbe9e7,stroke:#d84315,color:#1a1a1a
    classDef warn fill:#fff3e0,stroke:#ef6c00,color:#1a1a1a

    S([start]) --> A{ramdisk_dir<br/>variable empty?}:::dec
    A -- yes --> X3([exit 3]):::term
    A -- no --> B{ramdisk_dir<br/>exists?}:::dec
    B -- no --> X4([exit 4]):::term
    B -- yes --> C{ramdisk_dir<br/>empty?}:::dec
    C -- yes --> W["echo [WARNING] RAM disk directory is empty!"]:::warn
    C -- no --> D
    W --> D[mkdir -p source_dir]:::act
    D --> E["RSYNC_CMD=(rsync -a)<br/>+ -v / --dry-run from $1<br/>+ --exclude=… per pattern<br/>+ --delete RAM/ SRC/"]:::act
    E --> F[exec rsync]:::act --> R([exit rsync status])
```

!!! danger "The WARNING branch is the data-loss path"
    An empty `ramdisk_dir` reaches `rsync --delete` and empties `source_dir`.
    See [Data safety model](data-safety.md).

## Process state machine (1.0.0, with signal detail)

```mermaid
stateDiagram-v2
    [*] --> Initialising
    Initialising --> Failed : missing rsync / config / source_dir
    Initialising --> Generated : worker scripts written
    Generated --> [*] : --script-gen-only
    Generated --> Copying
    Copying --> Failed : cp status ≠ 0
    Copying --> OneShotSync : --one-time
    OneShotSync --> CleaningUp : exit 0 (EXIT trap)
    Copying --> Waiting
    state "Main loop" as Loop {
        Waiting --> Syncing : timeout (or stdin EOF)
        Syncing --> Waiting
        Waiting --> Breaking : key press
    }
    Breaking --> CleaningUp : return from run_sync_loop
    Waiting --> CleaningUp : SIGINT / SIGTERM (trap)
    CleaningUp --> Waiting : trap returns (1.0.0 only, CLEANUP_NEEDED=false)
    CleaningUp --> [*] : EXIT
    Failed --> [*] : exit 1
```

## Signal and exit handling

| Event | 1.0.0 behaviour | 1.1.0 target |
|-------|-----------------|--------------|
| Key press on stdin | loop breaks, final sync, exit 0 | kept when stdin is a TTY |
| `SIGINT` (Ctrl+C) | `cleanup` runs (final sync, report); loop resumes; second Ctrl+C during `read` breaks the loop | flag set, `sleep` killed, loop exits, one `cleanup`, exit 0 |
| `SIGTERM` | same as SIGINT — process does not exit | as SIGINT |
| `SIGUSR1` | default action (terminates without cleanup) | immediate sync-back, loop continues |
| `SIGHUP` | default action (terminates without cleanup) | ignore or reload config — to be decided |
| `exit N` anywhere | `EXIT` trap → `cleanup` if `CLEANUP_NEEDED` | unchanged |
