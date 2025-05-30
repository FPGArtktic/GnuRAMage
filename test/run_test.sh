#!/bin/bash
# Test script for GnuRAMage.sh
# Automatically verifies the correct operation of the program

# Colors for console display
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to display test headers
print_header() {
    echo -e "\n${YELLOW}=====================================${RESET}"
    echo -e "${YELLOW}$1${RESET}"
    echo -e "${YELLOW}=====================================${RESET}"
}

# Function to report test results
report_test() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ "$result" = "PASS" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ PASS:${RESET} $test_name - $message"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ FAIL:${RESET} $test_name - $message"
    fi
}

# Function to display summary
print_summary() {
    echo -e "\n${YELLOW}===== TEST SUMMARY =====${RESET}"
    echo -e "Tests executed: $TESTS_TOTAL"
    echo -e "${GREEN}Tests passed: $TESTS_PASSED${RESET}"
    echo -e "${RED}Tests failed: $TESTS_FAILED${RESET}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}ALL TESTS PASSED SUCCESSFULLY!${RESET}"
        exit 0
    else
        echo -e "\n${RED}SOME TESTS FAILED!${RESET}"
        exit 1
    fi
}

# Function to clean up the test environment
cleanup() {
    echo "Cleaning up test environment..."
    rm -rf /tmp/ram_disk_test_source /tmp/ram_disk_test_ramdisk
    rm -f ../gramage_sync_to_disk.sh ../gramage_copy_to_ram.sh
}

# Check if the program exists
check_program_exists() {
    print_header "TEST 1: Checking program existence"
    
    if [ -f "../gramage.sh" ]; then
        report_test "Program existence" "PASS" "gramage.sh file exists"
    else
        report_test "Program existence" "FAIL" "gramage.sh file does not exist"
        print_summary
        exit 1
    fi
    
    if [ -x "../gramage.sh" ]; then
        report_test "Program permissions" "PASS" "gramage.sh has execution permissions"
    else
        report_test "Program permissions" "FAIL" "gramage.sh does not have execution permissions"
        chmod +x ../gramage.sh
        report_test "Fix permissions" "PASS" "Added execution permissions"
    fi
}

# Check script generation
check_script_generation() {
    print_header "TEST 2: Checking script generation"
    
    # Remove existing scripts
    rm -f ../gramage_sync_to_disk.sh ../gramage_copy_to_ram.sh
    
    # Create source directory first to ensure script generation works
    mkdir -p /tmp/ram_disk_test_source
    
    # Generate scripts only
    ../gramage.sh --config gramage_test.ini --script-gen-only
    
    if [ -f "../gramage_sync_to_disk.sh" ]; then
        report_test "Generating gramage_sync_to_disk.sh" "PASS" "gramage_sync_to_disk.sh script was generated"
    else
        report_test "Generating gramage_sync_to_disk.sh" "FAIL" "gramage_sync_to_disk.sh script was not generated"
    fi
    
    if [ -f "../gramage_copy_to_ram.sh" ]; then
        report_test "Generating gramage_copy_to_ram.sh" "PASS" "gramage_copy_to_ram.sh script was generated"
    else
        report_test "Generating gramage_copy_to_ram.sh" "FAIL" "gramage_copy_to_ram.sh script was not generated"
    fi
    
    if [ -x "../gramage_sync_to_disk.sh" ] && [ -x "../gramage_copy_to_ram.sh" ]; then
        report_test "Script permissions" "PASS" "Both scripts have execution permissions"
    else
        report_test "Script permissions" "FAIL" "Scripts do not have execution permissions"
    fi
}

# Test environment and directories
test_environment() {
    print_header "TEST 3: Testing environment and directories"
    
    # Generate test environment
    ./test_generator.sh
    
    if [ -d "/tmp/ram_disk_test_source" ]; then
        report_test "Source directory" "PASS" "Directory /tmp/ram_disk_test_source exists"
    else
        report_test "Source directory" "FAIL" "Directory /tmp/ram_disk_test_source does not exist"
    fi
    
    # Check if there are files in the source directory
    SOURCE_FILES=$(find /tmp/ram_disk_test_source -type f | wc -l)
    if [ "$SOURCE_FILES" -gt 0 ]; then
        report_test "Source files" "PASS" "Found $SOURCE_FILES files in source directory"
    else
        report_test "Source files" "FAIL" "No files in source directory"
    fi
}

# Test copying from hard disk to RAM disk
test_copy_to_ramdisk() {
    print_header "TEST 4: Testing copying from hard disk to RAM disk"
    
    # Run the copy script
    if [ ! -f "../gramage_copy_to_ram.sh" ]; then
        # Run the main script to generate the scripts
        ../gramage.sh --config gramage_test.ini --script-gen-only
    fi
    
    ../gramage_copy_to_ram.sh --verbose
    
    if [ -d "/tmp/ram_disk_test_ramdisk" ]; then
        report_test "RAM disk directory" "PASS" "Directory /tmp/ram_disk_test_ramdisk exists"
    else
        report_test "RAM disk directory" "FAIL" "Directory /tmp/ram_disk_test_ramdisk does not exist"
    fi
    
    # Check if there are files in the RAM disk directory
    RAMDISK_FILES=$(find /tmp/ram_disk_test_ramdisk -type f | wc -l)
    if [ "$RAMDISK_FILES" -gt 0 ]; then
        report_test "Files on RAM disk" "PASS" "Found $RAMDISK_FILES files on RAM disk"
    else
        report_test "Files on RAM disk" "FAIL" "No files on RAM disk"
    fi
}

# Test synchronization from RAM disk to hard disk
test_sync_to_disk() {
    print_header "TEST 5: Testing synchronization from RAM disk to hard disk"
    
    # Create an additional file on RAM disk to check synchronization
    echo "Test synchronization" > "/tmp/ram_disk_test_ramdisk/test_sync_file.txt"
    
    # Run the synchronization script
    if [ ! -f "../gramage_sync_to_disk.sh" ]; then
        # Run the main script to generate the scripts
        ../gramage.sh --config gramage_test.ini --script-gen-only
    fi
    
    ../gramage_sync_to_disk.sh --verbose
    
    # Check if the test file was synchronized to the hard disk
    if [ -f "/tmp/ram_disk_test_source/test_sync_file.txt" ]; then
        report_test "File synchronization" "PASS" "Test file was synchronized to the hard disk"
    else
        report_test "File synchronization" "FAIL" "Test file was not synchronized to the hard disk"
    fi
}

# Test file exclusion patterns
test_exclude_patterns() {
    print_header "TEST 6: Testing file exclusion patterns"
    
    # Create files that should be excluded
    touch "/tmp/ram_disk_test_ramdisk/excluded_file.bak"
    touch "/tmp/ram_disk_test_ramdisk/excluded_file.tmp"
    touch "/tmp/ram_disk_test_ramdisk/temp_excluded_file.txt"
    mkdir -p "/tmp/ram_disk_test_ramdisk/test_ignore_dir"
    touch "/tmp/ram_disk_test_ramdisk/test_ignore_dir/file_in_ignored_dir.txt"
    
    # Run the synchronization script
    if [ ! -f "../gramage_sync_to_disk.sh" ]; then
        # Run the main script to generate the scripts
        ../gramage.sh --config gramage_test.ini --script-gen-only
    fi
    
    ../gramage_sync_to_disk.sh --verbose
    
    # Check if files that should be excluded were not synchronized
    EXCLUDED_FILES=0
    [ ! -f "/tmp/ram_disk_test_source/excluded_file.bak" ] && EXCLUDED_FILES=$((EXCLUDED_FILES + 1))
    [ ! -f "/tmp/ram_disk_test_source/excluded_file.tmp" ] && EXCLUDED_FILES=$((EXCLUDED_FILES + 1))
    [ ! -f "/tmp/ram_disk_test_source/temp_excluded_file.txt" ] && EXCLUDED_FILES=$((EXCLUDED_FILES + 1))
    [ ! -f "/tmp/ram_disk_test_source/test_ignore_dir/file_in_ignored_dir.txt" ] && EXCLUDED_FILES=$((EXCLUDED_FILES + 1))
    
    if [ "$EXCLUDED_FILES" -eq 4 ]; then
        report_test "File exclusion" "PASS" "All files were correctly excluded from synchronization"
    else
        report_test "File exclusion" "FAIL" "Not all files were excluded from synchronization ($EXCLUDED_FILES/4)"
    fi
}

# Test main script in one-time mode
test_main_script() {
    print_header "TEST 7: Testing main script in one-time mode"
    
    # Clean directories
    rm -rf /tmp/ram_disk_test_ramdisk/*
    
    # Run the main script in one-time mode
    ../gramage.sh --config gramage_test.ini --one-time
    
    # Check if files were copied to RAM disk
    RAMDISK_FILES=$(find /tmp/ram_disk_test_ramdisk -type f | wc -l)
    if [ "$RAMDISK_FILES" -gt 0 ]; then
        report_test "File copying by main script" "PASS" "Found $RAMDISK_FILES files on RAM disk"
    else
        report_test "File copying by main script" "FAIL" "No files on RAM disk"
    fi
    
    # Create an additional file on RAM disk to check synchronization
    echo "Testing main script" > "/tmp/ram_disk_test_ramdisk/test_main_script.txt"
    
    # Run the main script again
    ../gramage.sh --config gramage_test.ini --one-time
    
    # Check if the test file was synchronized to the hard disk
    if [ -f "/tmp/ram_disk_test_source/test_main_script.txt" ]; then
        report_test "Synchronization by main script" "PASS" "Test file was synchronized to the hard disk"
    else
        report_test "Synchronization by main script" "FAIL" "Test file was not synchronized to the hard disk"
    fi
}

# Test log generation
test_logging() {
    print_header "TEST 8: Testing log generation"
    
    # Temporary log files for testing
    LOG_FILE="/tmp/ram_disk_test_logs.txt"
    ERROR_LOG_FILE="/tmp/ram_disk_test_errors.txt"
    
    # Remove log files if they exist
    rm -f "$LOG_FILE" "$ERROR_LOG_FILE"
    
    # Run the script with logging options
    ../gramage.sh --config gramage_test.ini --one-time --logs "$LOG_FILE" --errors-log "$ERROR_LOG_FILE"
    
    # Check if the log file was created
    if [ -f "$LOG_FILE" ]; then
        LOG_SIZE=$(wc -c < "$LOG_FILE")
        if [ "$LOG_SIZE" -gt 0 ]; then
            report_test "Log file creation" "PASS" "Log file was created and contains data (size: $LOG_SIZE bytes)"
        else
            report_test "Log file creation" "FAIL" "Log file was created but is empty"
        fi
    else
        report_test "Log file creation" "FAIL" "Log file was not created"
    fi
    
    # Check if the error log file was created
    if [ -f "$ERROR_LOG_FILE" ]; then
        ERROR_LOG_SIZE=$(wc -c < "$ERROR_LOG_FILE")
        report_test "Error log file creation" "PASS" "Error log file was created (size: $ERROR_LOG_SIZE bytes)"
    else
        report_test "Error log file creation" "FAIL" "Error log file was not created"
    fi
    
    # Check if logs contain expected information
    if [ -f "$LOG_FILE" ]; then
        if grep -q "INFO" "$LOG_FILE"; then
            report_test "INFO log content" "PASS" "Logs contain INFO level entries"
        else
            report_test "INFO log content" "FAIL" "Logs do not contain INFO level entries"
        fi
        
        if grep -q "DEBUG" "$LOG_FILE"; then
            report_test "DEBUG log content" "PASS" "Logs contain DEBUG level entries"
        else
            report_test "DEBUG log content" "FAIL" "Logs do not contain DEBUG level entries"
        fi
    fi
    
    # Generate an artificial error to test error logs
    # Create a read-only file to force an error during synchronization
    mkdir -p "/tmp/ram_disk_test_ramdisk/readonly_dir"
    touch "/tmp/ram_disk_test_ramdisk/readonly_dir/readonly_file.txt"
    chmod 444 "/tmp/ram_disk_test_ramdisk/readonly_dir"
    
    # Run the script again to generate errors
    ../gramage.sh --config gramage_test.ini --one-time --logs "$LOG_FILE" --errors-log "$ERROR_LOG_FILE"
    
    # Restore permissions
    chmod 755 "/tmp/ram_disk_test_ramdisk/readonly_dir"
    
    # Check if error logs contain information about errors
    if [ -f "$ERROR_LOG_FILE" ]; then
        if grep -q "ERROR\|WARN\|Error log file initialized" "$ERROR_LOG_FILE"; then
            report_test "Error log content" "PASS" "Error logs contain appropriate entries"
        else
            report_test "Error log content" "FAIL" "Error logs do not contain ERROR or WARN level entries"
        fi
    fi
    
    # Remove log files
    rm -f "$LOG_FILE" "$ERROR_LOG_FILE"
}

# Main test function
run_tests() {
    echo -e "${YELLOW}=====================================${RESET}"
    echo -e "${YELLOW}STARTING GNURAMAGE TESTS${RESET}"
    echo -e "${YELLOW}=====================================${RESET}"
    
    # Clean environment before starting tests
    cleanup
    
    # Run all tests
    check_program_exists
    check_script_generation
    test_environment
    test_copy_to_ramdisk
    test_sync_to_disk
    test_exclude_patterns
    test_main_script
    test_logging
    
    # Display summary
    print_summary
}

# Run tests
run_tests
