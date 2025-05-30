#!/bin/bash
# Test Generator for GnuRAMage
# Creates sample files and directory structures for testing

# Default values
TEST_SOURCE_DIR="/tmp/ram_disk_test_source"
TEST_RAMDISK_DIR="/tmp/ram_disk_test_ramdisk"
FILE_COUNT=20
DIR_COUNT=5
FILE_SIZE="10k"  # Default file size in KB
CONFIG_FILE="gnuramage_test.ini"

# Print usage information
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Test Generator for GnuRAMage"
    echo ""
    echo "Options:"
    echo "  --source <dir>     Path to the source directory (default: $TEST_SOURCE_DIR)"
    echo "  --ramdisk <dir>    Path to the RAM disk directory (default: $TEST_RAMDISK_DIR)"
    echo "  --files <count>    Number of files to create (default: $FILE_COUNT)"
    echo "  --dirs <count>     Number of directories to create (default: $DIR_COUNT)"
    echo "  --size <size>      Size of each file (default: $FILE_SIZE)"
    echo "  --config <file>    Path to write the test configuration (default: $CONFIG_FILE)"
    echo "  --help             Display this help message and exit"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --source)
            TEST_SOURCE_DIR="$2"
            shift 2
            ;;
        --ramdisk)
            TEST_RAMDISK_DIR="$2"
            shift 2
            ;;
        --files)
            FILE_COUNT="$2"
            shift 2
            ;;
        --dirs)
            DIR_COUNT="$2"
            shift 2
            ;;
        --size)
            FILE_SIZE="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            print_usage
            exit 1
            ;;
    esac
done

# Create test directories
echo "Creating test directories..."
mkdir -p "$TEST_SOURCE_DIR"
# Note: We don't create the RAM disk directory here as the main script should handle that

# Create random directories
echo "Creating $DIR_COUNT random directories..."
for ((i=1; i<=DIR_COUNT; i++)); do
    dir_name="dir_$i"
    mkdir -p "$TEST_SOURCE_DIR/$dir_name"
    
    # Create subdirectories with random depth
    depth=$((RANDOM % 3 + 1))
    subdir="$TEST_SOURCE_DIR/$dir_name"
    for ((j=1; j<=depth; j++)); do
        subdir="$subdir/subdir_$j"
        mkdir -p "$subdir"
    done
done

# Create random files
echo "Creating $FILE_COUNT random files..."
for ((i=1; i<=FILE_COUNT; i++)); do
    # Decide whether to put the file in a directory or the root
    if [ $((RANDOM % 3)) -eq 0 ] || [ $DIR_COUNT -eq 0 ]; then
        # Put in root
        file_path="$TEST_SOURCE_DIR/file_$i.txt"
    else
        # Put in a random directory
        dir_num=$((RANDOM % DIR_COUNT + 1))
        dir_path="$TEST_SOURCE_DIR/dir_$dir_num"
        
        # Check if there are subdirectories
        subdirs=($(find "$dir_path" -type d))
        if [ ${#subdirs[@]} -gt 1 ]; then
            # Pick a random subdirectory
            subdir_index=$((RANDOM % ${#subdirs[@]}))
            file_path="${subdirs[$subdir_index]}/file_$i.txt"
        else
            file_path="$dir_path/file_$i.txt"
        fi
    fi
    
    # Create file with random content
    dd if=/dev/urandom of="$file_path" bs="$FILE_SIZE" count=1 status=none
    echo "Created: $file_path"
done

# Create a special .rsyncignore file
echo "Creating .rsyncignore file..."
cat > "$TEST_SOURCE_DIR/.rsyncignore" << EOF
# Test ignore patterns
*.bak
*.tmp
temp_*
test_ignore_dir/
EOF

# Create some files that should be ignored
echo "Creating files that should be ignored..."
mkdir -p "$TEST_SOURCE_DIR/test_ignore_dir"
touch "$TEST_SOURCE_DIR/file1.bak"
touch "$TEST_SOURCE_DIR/file2.tmp"
touch "$TEST_SOURCE_DIR/temp_file.txt"
touch "$TEST_SOURCE_DIR/test_ignore_dir/should_be_ignored.txt"

# Create a test config file
echo "Creating test configuration file: $CONFIG_FILE"
cat > "$CONFIG_FILE" << EOF
# GnuRAMage Test Configuration File

[SETTINGS]
# Interval between synchronizations in seconds (short for testing)
sync_interval = 10

# Log level: ERROR, WARN, INFO, DEBUG
log_level = DEBUG

# Verify checksums during sync (test both true and false)
verify_checksums = true

[DIRECTORIES]
# Source directory on hard disk
source_dir = $TEST_SOURCE_DIR

# Target directory on RAM disk
ramdisk_dir = $TEST_RAMDISK_DIR

[EXCLUDE]
# Patterns to exclude from synchronization
# Each line is a pattern in rsync format
*.bak
*.tmp
temp_*
test_ignore_dir/
EOF

echo "Test environment setup complete!"
echo "Created $FILE_COUNT files across $DIR_COUNT directories"
echo ""
echo "To use the test environment, run:"
echo "../gramage.sh --config ../test/$CONFIG_FILE"
echo ""
echo "For a dry run test first, use:"
echo "../gramage.sh --config ../test/$CONFIG_FILE --dry-run --verbose"
