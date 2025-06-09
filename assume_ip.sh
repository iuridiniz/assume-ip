#!/bin/bash
# vim: set ts=2 sw=2 et:

# Exit immediately if a command exits with a non-zero status.
set -e
# The return value of a pipeline is the status of the last command to exit with a non-zero status,
# or zero if all commands in the pipeline exit successfully.
set -o pipefail

# set -x # Uncomment for full bash debugging (very verbose)

DEFAULT_SCAN_INTERVAL_SECONDS=10 # Default scan interval in seconds
DEFAULT_LOG_LEVEL="INFO" # Default log level

# Variables to hold final configuration
#TARGET_MAC=""
#TARGET_IP=""
#INTERFACE=""
#SCAN_INTERVAL_SECONDS=""
#LOG_LEVEL=""
DRY_RUN=false
RUN_ONCE=false
QUIET_MODE=false # Quiet mode will override log level setting for non-critical messages
OMIT_DATETIME=false # New: Flag to omit datetime from logs. Default: false (datetime enabled)
MIN_LOG_LEVEL_NUM=1 # Default to INFO (see log_level_to_num mapping below)

# Define the full path to arp-scan as it's often in /usr/sbin, not typically in a regular user's PATH.
ARP_SCAN_PATH="/usr/sbin/arp-scan"

# Log level mapping for easier comparison
declare -A log_level_to_num
log_level_to_num[DEBUG]=0
log_level_to_num[INFO]=1
log_level_to_num[WARN]=2
log_level_to_num[ERROR]=3
log_level_to_num[CRITICAL]=4 # Critical messages ignore quiet mode and min_log_level

# Function to convert log level string to its numeric value
get_log_level_num() {
  local level_str="$1"
  echo "${log_level_to_num[$(echo "$level_str" | tr '[:lower:]' '[:upper:]')]}"
}

# Function to log messages
# $1: message string
# $2: message log level (e.g., "DEBUG", "INFO", "WARN", "ERROR"). Defaults to INFO.
# $3: (optional) true if critical message. Critical messages are always logged to stderr regardless of QUIET_MODE or MIN_LOG_LEVEL.
log_message() {
  local message="$1"
  local msg_level_str=${2:-"INFO"} # Default message level to INFO
  local is_critical=${3:-false} # Default to false if not provided

  local msg_level_num=$(get_log_level_num "$msg_level_str")

  local datetime_prefix=""
  if [ "$OMIT_DATETIME" = false ]; then
    datetime_prefix="$(date +'%Y-%m-%d %H:%M:%S') - "
  fi

  if $is_critical; then
    # Critical messages always go to stderr
    echo "${datetime_prefix}CRITICAL - $message" >&2
  elif ! $QUIET_MODE && (( msg_level_num >= MIN_LOG_LEVEL_NUM )); then
    # Non-critical messages go to stdout, only if not in quiet mode AND level is high enough
    echo "${datetime_prefix}$(echo "$msg_level_str" | tr '[:lower:]' '[:upper:]') - $message"
  fi
}

# Function to display usage information
display_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Monitors for a specific MAC address and manages an IP address on an interface."
  echo ""
  echo "Options:"
  echo "  -m <MAC_ADDRESS>   Target MAC address to monitor (e.g., 00:16:3e:c9:94:4f)"
  echo "                     (Overrides TARGET_MAC environment variable)"
  echo "  -i <IP_ADDRESS>    Target IP address to manage (e.g., 192.168.1.7)"
  echo "                     (Overrides TARGET_IP environment variable)"
  echo "  -n <INTERFACE>     Network interface (e.g., eth0)"
  echo "                     (Overrides INTERFACE environment variable)"
  echo "  -s <SECONDS>       Scan interval in seconds (default: $DEFAULT_SCAN_INTERVAL_SECONDS)"
  echo "                     (Overrides SCAN_INTERVAL_SECONDS environment variable)"
  echo "  --dry-run          Enable dry-run mode. Commands will be logged but not executed."
  echo "  --once             Run the script only once, then exit."
  echo "  -q, --quiet        Enable quiet mode. Suppresses all script output except errors."
  echo "  --log-level <LEVEL> Set minimum logging level (DEBUG, INFO, WARN, ERROR). Default: $DEFAULT_LOG_LEVEL"
  echo "  --omit-datetime    Omit datetime prefix from log messages. (Default: disabled)"
  echo "  -h, --help         Display this help message and exit."
  echo ""
  echo "Environment Variables (lower precedence than command-line arguments):"
  echo "  TARGET_MAC"
  echo "  TARGET_IP"
  echo "  INTERFACE"
  echo "  SCAN_INTERVAL_SECONDS"
  echo "  LOG_LEVEL"
  echo ""
  echo "Examples:"
  echo "  $0 -m 00:11:22:33:44:55 -i 192.168.1.100 -n eth0"
  echo "  TARGET_MAC=AA:BB:CC:DD:EE:FF $0 --once --log-level DEBUG"
  echo "  $0 -m 00:16:3e:c9:94:4f --dry-run -q --omit-datetime"
}

# --- Argument Parsing ---
# Set default values from script defaults
TARGET_MAC="${TARGET_MAC:-}"
TARGET_IP="${TARGET_IP:-}"
INTERFACE="${INTERFACE:-}"
SCAN_INTERVAL_SECONDS="${SCAN_INTERVAL_SECONDS:-$DEFAULT_SCAN_INTERVAL_SECONDS}"
LOG_LEVEL="${LOG_LEVEL:-$DEFAULT_LOG_LEVEL}"

# Parse command-line arguments
while (( "$#" )); do
  case "$1" in
    -m|--mac)
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        TARGET_MAC="$2"
        shift 2
      else
        log_message "Argument for $1 is missing." "ERROR" true # Critical error
        display_usage
        exit 1
      fi
      ;;
    -i|--ip)
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        TARGET_IP="$2"
        shift 2
      else
        log_message "Argument for $1 is missing." "ERROR" true # Critical error
        display_usage
        exit 1
      fi
      ;;
    -n|--interface)
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        INTERFACE="$2"
        shift 2
      else
        log_message "Argument for $1 is missing." "ERROR" true # Critical error
        display_usage
        exit 1
      fi
      ;;
    -s|--interval)
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        SCAN_INTERVAL_SECONDS="$2"
        shift 2
      else
        log_message "Argument for $1 is missing." "ERROR" true # Critical error
        display_usage
        exit 1
      fi
      ;;
    --log-level)
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        LOG_LEVEL="$2"
        shift 2
      else
        log_message "Argument for $1 is missing." "ERROR" true # Critical error
        display_usage
        exit 1
      fi
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --once)
      RUN_ONCE=true
      shift
      ;;
    -q|--quiet)
      QUIET_MODE=true
      shift
      ;;
    --omit-datetime) # New: Omit datetime option
      OMIT_DATETIME=true
      shift
      ;;
    -h|--help)
      display_usage
      exit 0
      ;;
    --) # End of all options.
      shift
      break
      ;;
    -*) # Unknown option
      log_message "Unknown option $1" "ERROR" true # Critical error
      display_usage
      exit 1
      ;;
    *) # Positional arguments (not used by this script)
      shift
      ;;
  esac
done

# Convert chosen LOG_LEVEL to numeric value for comparison
MIN_LOG_LEVEL_NUM=$(get_log_level_num "$LOG_LEVEL")
if [ -z "$MIN_LOG_LEVEL_NUM" ]; then
  log_message "Invalid log level specified: '$LOG_LEVEL'. Using default: $DEFAULT_LOG_LEVEL" "WARN" true # This is a critical warning
  MIN_LOG_LEVEL_NUM=$(get_log_level_num "$DEFAULT_LOG_LEVEL")
fi

# Validate required parameters
if [ -z "$TARGET_MAC" ] || [ -z "$TARGET_IP" ] || [ -z "$INTERFACE" ]; then
  log_message "Missing required parameters (MAC address, IP address, and network interface)." "ERROR" true # Critical error
  display_usage
  exit 1
fi

# Check for arp-scan presence using its full path
if ! [ -x "$ARP_SCAN_PATH" ]; then
  log_message "'arp-scan' command not found or not executable at '$ARP_SCAN_PATH'. Please install it." "ERROR" true # Critical error
  log_message "For Debian/Ubuntu: sudo apt-get install arp-scan" "INFO" true # Always show installation instructions
  log_message "For Fedora/RHEL/CentOS: sudo dnf install arp-scan" "INFO" true # Always show installation instructions
  exit 1
fi

# Check if the specified network interface exists
# ip link show will exit with 1 if interface is not found when `set -e` is active.
# We redirect stderr to /dev/null to avoid verbose output from ip link if it fails.
if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
  log_message "Network interface '$INTERFACE' not found. Please ensure the interface exists and is named correctly." "ERROR" true # Critical error
  exit 1
fi

# --- Core Functions ---

# Checks if the target MAC address is present at the target IP using arp-scan
check_mac_presence() {
  log_message "Scanning for MAC $TARGET_MAC at IP $TARGET_IP on interface $INTERFACE..." "DEBUG"
  # Redirecting stderr to /dev/null to avoid printing errors from arp-scan when it can't find anything
  arp_output=$("$ARP_SCAN_PATH" -l -q --retry=3 --interface="$INTERFACE" 2>/dev/null | grep "$TARGET_MAC")
  if echo "$arp_output" | grep -q "$TARGET_IP"; then
    log_message "MAC $TARGET_MAC found at IP $TARGET_IP." "DEBUG"
    return 0 # MAC and IP found
  else
    log_message "MAC $TARGET_MAC NOT found at IP $TARGET_IP." "DEBUG"
    return 1 # MAC or IP not found, or not associated as expected
  fi
}

# Adds the target IP to the interface
add_ip() {
  # Check if the IP is already present. ip addr show will return 0 even if it doesn't find the IP
  # if the interface exists, so we need to grep for the IP specifically.
  if ! ip addr show "$INTERFACE" | grep -q "inet $TARGET_IP/"; then
    log_message "IP $TARGET_IP not present on interface $INTERFACE." "DEBUG"
    if $DRY_RUN; then
      log_message "[DRY-RUN] Would execute: ip addr add \"$TARGET_IP\"/24 dev \"$INTERFACE\"" "INFO"
      return 0
    else
      log_message "Adding IP $TARGET_IP to interface $INTERFACE..." "INFO" # This message remains INFO
      ip addr add "$TARGET_IP"/24 dev "$INTERFACE"
      log_message "IP $TARGET_IP added successfully." "INFO" # This message remains INFO
      return 0
    fi
  else
    log_message "IP $TARGET_IP is already present on interface $INTERFACE." "DEBUG"
    return 0
  fi
}

# Removes the target IP from the interface
remove_ip() {
  # Check if the IP is present.
  if ip addr show "$INTERFACE" | grep -q "inet $TARGET_IP/"; then
    log_message "IP $TARGET_IP present on interface $INTERFACE." "DEBUG"
    if $DRY_RUN; then
      log_message "[DRY-RUN] Would execute: ip addr del \"$TARGET_IP\"/24 dev \"$INTERFACE\"" "INFO"
      return 0
    else
      log_message "Removing IP $TARGET_IP from interface $INTERFACE..." "INFO" # This message remains INFO
      ip addr del "$TARGET_IP"/24 dev "$INTERFACE"
      log_message "IP $TARGET_IP removed successfully." "INFO" # This message remains INFO
      return 0
    fi
  else
    log_message "IP $TARGET_IP is not present on interface $INTERFACE." "DEBUG"
    return 0
  fi
}

# Main monitoring loop
main() {
  # Initial messages are always logged, unless quiet mode is set from the start.
  # The log_message function itself handles suppression for subsequent calls.
  if ! $QUIET_MODE; then
    log_message "Starting MAC/IP monitoring for MAC: $TARGET_MAC, IP: $TARGET_IP, Interface: $INTERFACE." "INFO"
    if $DRY_RUN; then
      log_message "Running in DRY-RUN mode. No changes will be applied." "INFO"
    fi
    if $RUN_ONCE; then
      log_message "Running in ONCE mode. Script will exit after one check." "INFO"
    fi
  fi

  while true; do
    log_message "Performing network scan..." "DEBUG"
    if check_mac_presence; then
      log_message "MAC $TARGET_MAC found at IP $TARGET_IP. Ensuring additional IP is not present." "DEBUG"
      remove_ip
    else
      log_message "MAC $TARGET_MAC NOT found at IP $TARGET_IP. Adding the additional IP." "DEBUG"
      add_ip
    fi

    if $RUN_ONCE; then
      log_message "Once mode enabled. Exiting." "INFO"
      break
    fi

    log_message "Waiting for $SCAN_INTERVAL_SECONDS seconds before next scan..." "DEBUG"
    sleep "$SCAN_INTERVAL_SECONDS"
  done
}

# Check if the script is being executed as root. This script MUST be run as root.
if [ "$(id -u)" -eq 0 ]; then
  log_message "Script is running as root. This is required for network configuration commands." "INFO" true
else
  log_message "This script must be run as root. Please run with 'sudo $0 ...'." "ERROR" true
  exit 1
fi

# Execute the main function
main
