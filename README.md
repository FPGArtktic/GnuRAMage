# GnuRAMage - The GNU RAM Disk Synchronization Tool

<p align="center">
  <img src="docs/logo.png" alt="GnuRAMage Logo" width="500"/>
</p>

## What is GnuRAMage?

GnuRAMage is a sophisticated yet humble Bash tool that bridges the gap between your sluggish rotating rust (hard drives) and the blazing fast silicon heaven (RAM disks). It's like having a very diligent intern who never sleeps, constantly ensuring your files are where they should be, when they should be there.

This tool was born out of the necessity to manage multi-terabyte RAM disks without losing one's sanity or data. Because let's face it, having terabytes of RAM without proper synchronization is like having a Ferrari without brakes - exciting, but ultimately catastrophic.

## Table of Contents

- [What is GnuRAMage?](#what-is-gnuramage)
- [Features](#features)
- [Why Would You Want This?](#why-would-you-want-this)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Examples](#examples)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)
- [Author](#author)

## Features

GnuRAMage comes packed with features that would make even the most demanding sysadmin shed a tear of joy:

- **Automatic File Copying**: Intelligently copies files from hard disk to RAM disk (because manual copying is for peasants)
- **Periodic Synchronization**: Regular sync-back to hard disk (because RAM is volatile, unlike our commitment to data integrity)
- **Exclusion Patterns**: Support for excluding files and directories (because not everything deserves the RAM treatment)
- **INI Configuration**: Human-readable configuration format (unlike some tools that use hieroglyphics)
- **Comprehensive Logging**: Multiple log levels and optional error-only logs (for when you want to pretend everything is fine)
- **Dry Run Mode**: Test operations without actually doing anything (for the cautious and the paranoid)
- **One-time Mode**: Single synchronization cycle (for those commitment-phobic moments)
- **Signal Handling**: Graceful shutdown on interruption (because even tools need manners)
- **Checksum Verification**: Optional data integrity checks (for the truly paranoid)
- **Script Generation**: Creates standalone scripts for automation (delegation at its finest)

## Why Would You Want This?

### The Problem
You have a massive RAM disk - perhaps several terabytes of the finest DDR5 money can buy. You want to use it for frequently accessed files to achieve ludicrous speed improvements. But you also don't want to lose your data when the power goes out, the cat trips over the power cord, or the universe decides to have a cosmic ray event.

### The Solution
GnuRAMage acts as your faithful guardian, ensuring that:
1. Your files get copied to the RAM disk for blazing fast access
2. Changes are periodically synchronized back to persistent storage
3. Your data survives power outages, system crashes, and acts of feline interference
4. You can sleep peacefully knowing your multi-thousand-dollar RAM investment is properly protected

### The GNU Way
In true GNU tradition, GnuRAMage is:
- **Free** (as in freedom, not as in "free puppy that costs $500/month in food")
- **Extensible** (modify it to your heart's content)
- **Well-documented** (this README is proof of our commitment to verbosity)
- **Standards-compliant** (follows POSIX where possible, and good sense everywhere else)

## Requirements

- **Bash**: Version 4.0 or later (because life's too short for ancient shells)
- **rsync**: The Swiss Army knife of file synchronization
- **GNU/Linux**: Any reasonably modern distribution (we're not picky, but we have standards)
- **Sufficient RAM**: Ideally measured in terabytes, but we won't judge your modest gigabytes
- **Coffee**: Optional but highly recommended for optimal performance (applies to both you and the system)

## Installation

### The Traditional Way

1. Clone this repository (or download it like it's 1999):
   ```bash
   git clone <repository-url>
   cd priv_ram_disk
   ```

2. Make the script executable (because files don't execute themselves):
   ```bash
   chmod +x gramage.sh
   ```

3. Edit the configuration file to match your setup:
   ```bash
   cp GnuRAMage.ini.example GnuRAMage.ini
   $EDITOR GnuRAMage.ini
   ```

### The Lazy Way

```bash
wget <direct-link-to-script>
chmod +x gramage.sh
# Edit configuration as needed
```

## Configuration

GnuRAMage uses an INI-style configuration file that's so simple, even a Windows user could understand it. The file is divided into logical sections:

### [SETTINGS] Section

```ini
# How often to sync (in seconds). 180 = 3 minutes of procrastination
sync_interval = 180

# Log verbosity: ERROR (silent treatment), WARN (passive aggressive),
# INFO (chatty), DEBUG (verbose to the point of annoyance)
log_level = INFO

# Verify checksums? true = paranoid but safe, false = living dangerously
verify_checksums = false
```

### [DIRECTORIES] Section

```ini
# Where your precious files currently live (the slow storage)
source_dir = /path/to/your/slow/storage

# Where your files will achieve enlightenment (the fast storage)
ramdisk_dir = /path/to/your/blazing/fast/ramdisk
```

### [EXCLUDE] Section

Patterns for files you don't want cluttering your precious RAM:

```ini
# Backup files (because backup-of-backups is just hoarding)
*.bak
*.tmp

# Temporary files (the digital equivalent of junk mail)
temp_*

# That one directory you created and forgot about
forgotten_project_from_2019/
```

### [CRON] Section

```ini
# When to run automatic syncs (cron format)
# Default: every 5 minutes (because patience is overrated)
schedule = */5 * * * *
```

## Usage

### Basic Syntax

```bash
./gramage.sh [OPTIONS]
```

### Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--config <file>` | Use custom config file | `--config my_setup.ini` |
| `--dry-run` | Simulate without actual changes | Perfect for the commitment-phobic |
| `--verbose` or `-v` | Detailed output | For when you want to know everything |
| `--logs <file>` | Write logs to file | `--logs sync.log` |
| `--errors-log <file>` | Separate error log | `--errors-log errors.log` |
| `--script-gen-only` | Generate scripts and exit | For the delegation enthusiasts |
| `--one-time` | Single sync cycle | One and done |
| `--help` | Display help | When all else fails |

## Examples

### Basic Operation

Start GnuRAMage with default settings:
```bash
./gramage.sh
```

This will:
1. Read `GnuRAMage.ini`
2. Copy files to RAM disk
3. Start periodic synchronization
4. Run until interrupted (Ctrl+C like a civilized person)

### Paranoid Mode

Run with verbose output and comprehensive logging:
```bash
./gramage.sh --verbose --logs detailed.log --errors-log problems.log
```

### Test Drive

Try before you buy with dry-run mode:
```bash
./gramage.sh --dry-run --verbose
```

This shows you what would happen without actually doing it - like a preview of your life choices.

### One-Shot Sync

For those commitment-averse moments:
```bash
./gramage.sh --one-time --verbose
```

### Script Generation Only

Generate automation scripts without starting the sync:
```bash
./gramage.sh --script-gen-only
```

This creates:
- `gramage_copy_to_ram.sh` - Initial copy script
- `gramage_sync_to_disk.sh` - Periodic sync script

Perfect for integrating with your existing automation or cron jobs.

### Custom Configuration

Use a different configuration file:
```bash
./gramage.sh --config production.ini --logs production.log
```

## Testing

We've included a comprehensive test suite because untested code is like unverified file transfers - a recipe for disaster.

### Running Tests

```bash
cd test
./run_test.sh
```

The test suite verifies:
- Script existence and permissions (basic sanity checks)
- Configuration parsing (because INI files can be tricky)
- Script generation (delegation functionality)
- File operations (the core purpose of our existence)
- Exclusion patterns (making sure ignored files stay ignored)
- Logging functionality (documenting our achievements and failures)

### Test Environment Generator

Create a test environment with sample files:
```bash
cd test
./test_generator.sh --files 100 --dirs 10 --size 1M
```

This creates a realistic test environment with:
- Multiple directories with nested structures
- Various file types and sizes
- Files that should be excluded (to test our exclusion logic)

## How It Works

### The Philosophy

GnuRAMage follows the UNIX philosophy: do one thing and do it well. That one thing happens to be "make your files faster while keeping them safe," which admittedly is more like two things, but who's counting?

### The Process

1. **Initialization**: Parse configuration, check dependencies, validate paths
2. **Initial Copy**: Copy files from slow storage to fast storage
3. **Monitoring Loop**: Periodically sync changes back to persistent storage
4. **Graceful Shutdown**: On interruption, perform final sync and cleanup

### The Magic

- Uses `rsync` for efficient synchronization (because reinventing the wheel is overrated)
- Employs intelligent exclusion patterns (your `.tmp` files don't deserve RAM)
- Provides comprehensive logging (for debugging and bragging rights)
- Handles signals gracefully (manners matter, even in code)

## Troubleshooting

### Common Issues

**"rsync not found"**
- Install rsync: `sudo apt-get install rsync` (Debian/Ubuntu) or equivalent

**"Permission denied"**
- Check file permissions: `chmod +x gramage.sh`
- Verify directory access rights

**"Configuration file not found"**
- Ensure `GnuRAMage.ini` exists in the script directory
- Use `--config` to specify a different location

**"RAM disk not mounted"**
- Verify your RAM disk is properly mounted
- Check mount points with `mount | grep tmpfs`

### Getting Help

1. Read this README (you're already doing great!)
2. Check the logs (they're surprisingly informative)
3. Use `--dry-run --verbose` to see what's happening
4. File an issue (we're surprisingly responsive)

## Contributing

Contributions are welcome! This is free software, after all. Whether you want to:

- Fix bugs (our favorite kind of contribution)
- Add features (preferably ones that make sense)
- Improve documentation (because more words are always better)
- Write tests (the unsung heroes of software development)

Please follow these guidelines:

1. **Follow GNU coding standards** (or at least pretend to)
2. **Write tests** (your future self will thank you)
3. **Update documentation** (this README won't update itself)
4. **Use meaningful commit messages** ("fix stuff" is not meaningful)

### Code Style

- Use 4 spaces for indentation (not tabs, we're not barbarians)
- Comment your code (future you is practically a different person)
- Follow existing conventions (consistency is key)
- Keep functions focused (do one thing well)

## Reporting Bugs

Found a bug? Congratulations! You've contributed to the improvement of this software. Please report it with:

1. **Clear description** of the problem
2. **Steps to reproduce** (be specific)
3. **Expected vs actual behavior**
4. **Log files** if available
5. **System information** (OS, RAM size, phase of moon)

## Future Enhancements

Ideas for future versions (contributions welcome):

- **Web interface** (because everything needs a web interface these days)
- **Real-time monitoring** (for the dashboard enthusiasts)
- **Multiple RAM disk support** (because more is always better)
- **Compression support** (squeeze more files into that precious RAM)
- **Network synchronization** (for the distributed storage aficionados)

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

### In Plain English

- **Use it** for whatever you want (commercial, personal, world domination)
- **Modify it** to your heart's content
- **Share it** with friends, enemies, and random strangers
- **Don't blame us** if it breaks something (though we tried really hard to make it not break things)

## Author

**Mateusz Okulanis**  
Email: FPGArtktic@outlook.com

Creator, maintainer, and chief RAM disk enthusiast. Available for consulting, debugging sessions, and philosophical discussions about the nature of persistent vs. volatile storage.

---

*"In a world full of slow storage, be the RAM disk synchronization tool."* - Ancient GNU Proverb (probably)

**Note**: This software was developed with love, caffeine, and an unhealthy obsession with making things faster. Use responsibly.
