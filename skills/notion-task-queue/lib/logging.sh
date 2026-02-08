#!/bin/bash
# Shared logging library for notion-task-queue scripts
# Source this at the top of scripts: source "$(dirname "$0")/lib/logging.sh"

LOG_DIR="/root/nyx/logs/notion-task-queue"
mkdir -p "$LOG_DIR"

# Get today's log file
get_log_file() {
  echo "${LOG_DIR}/$(date +%Y-%m-%d).log"
}

# Log a message with timestamp and level
# Usage: log_msg "INFO" "message" or log_info "message"
log_msg() {
  local LEVEL="$1"
  local MSG="$2"
  local SCRIPT_NAME="${3:-$(basename "$0")}"
  local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  local LOG_FILE=$(get_log_file)
  
  echo "[${TIMESTAMP}] [${LEVEL}] [${SCRIPT_NAME}] ${MSG}" >> "$LOG_FILE"
  
  # Also write errors to stderr for immediate visibility
  if [ "$LEVEL" = "ERROR" ] || [ "$LEVEL" = "TIMEOUT" ]; then
    echo "[${LEVEL}] ${MSG}" >&2
  fi
}

log_info() {
  log_msg "INFO" "$1" "${2:-}"
}

log_warn() {
  log_msg "WARN" "$1" "${2:-}"
}

log_error() {
  log_msg "ERROR" "$1" "${2:-}"
}

log_timeout() {
  log_msg "TIMEOUT" "$1" "${2:-}"
}

log_debug() {
  # Only log debug if DEBUG_LOGGING is set
  if [ "${DEBUG_LOGGING:-}" = "1" ]; then
    log_msg "DEBUG" "$1" "${2:-}"
  fi
}

# Log script start with context
log_start() {
  local CONTEXT="${1:-}"
  log_info "Script started${CONTEXT:+ - }${CONTEXT}"
}

# Log script completion with optional stats
log_complete() {
  local STATS="${1:-}"
  log_info "Script completed${STATS:+ - }${STATS}"
}

# Log API error from Notion response
log_api_error() {
  local ENDPOINT="$1"
  local RESPONSE="$2"
  local ERROR_MSG=$(echo "$RESPONSE" | jq -r '.message // "Unknown error"' 2>/dev/null)
  local ERROR_CODE=$(echo "$RESPONSE" | jq -r '.code // "unknown"' 2>/dev/null)
  log_error "Notion API error on ${ENDPOINT}: [${ERROR_CODE}] ${ERROR_MSG}"
}

# Tail recent logs (useful for debugging)
tail_logs() {
  local LINES="${1:-50}"
  tail -n "$LINES" "$(get_log_file)" 2>/dev/null || echo "No logs yet today"
}
