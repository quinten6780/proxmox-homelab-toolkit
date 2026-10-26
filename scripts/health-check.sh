#!/bin/bash
# health-check.sh - Check all homelab services and alert on failure
# Usage: ./health-check.sh [--email EMAIL] [--webhook URL]

set -euo pipefail

EMAIL="${EMAIL:-}"
WEBHOOK="${WEBHOOK:-}"
LOG_FILE="/var/log/homelab-health.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

FAILED=0
REPORT=""

check_service() {
    local name="$1"
    local check_cmd="$2"
    if eval "$check_cmd" &>/dev/null; then
        log "  ${GREEN}✓${NC} $name: OK"
        REPORT+="✓ $name: OK\n"
    else
        log "  ${RED}✗${NC} $name: FAILED"
        REPORT+="✗ $name: FAILED\n"
        ((FAILED++))
    fi
}

log "=== Homelab Health Check ==="

# Check Proxmox
check_service "Proxmox API" "curl -sk https://localhost:8006/api2/json/version | grep -q release"

# Check containers
for ct in $(pct list | awk 'NR>1 {print $1}'); do
    name=$(pct config "$ct" | grep hostname | cut -d: -f2 | tr -d ' ')
    check_service "Container $ct ($name)" "pct status $ct | grep -q running"
done

# Check VMs
for vm in $(qm list | awk 'NR>1 {print $1}'); do
    name=$(qm config "$vm" | grep name | cut -d: -f2 | tr -d ' ')
    check_service "VM $vm ($name)" "qm status $vm | grep -q running"
done

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_USAGE" -lt 90 ]; then
    log "  ${GREEN}✓${NC} Disk space: ${DISK_USAGE}% used"
    REPORT+="✓ Disk space: ${DISK_USAGE}% used\n"
else
    log "  ${RED}✗${NC} Disk space: ${DISK_USAGE}% used (CRITICAL)"
    REPORT+="✗ Disk space: ${DISK_USAGE}% used (CRITICAL)\n"
    ((FAILED++))
fi

# Check memory
MEM_USAGE=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
if [ "$MEM_USAGE" -lt 90 ]; then
    log "  ${GREEN}✓${NC} Memory: ${MEM_USAGE}% used"
    REPORT+="✓ Memory: ${MEM_USAGE}% used\n"
else
    log "  ${RED}✗${NC} Memory: ${MEM_USAGE}% used (WARNING)"
    REPORT+="✗ Memory: ${MEM_USAGE}% used (WARNING)\n"
    ((FAILED++))
fi

# Summary
log ""
if [ $FAILED -eq 0 ]; then
    log "${GREEN}All checks passed.${NC}"
else
    log "${RED}$FAILED check(s) failed!${NC}"
    
    # Send alert
    if [ -n "$EMAIL" ]; then
        echo -e "$REPORT" | mail -s "Homelab Health Alert: $FAILED failures" "$EMAIL"
    fi
    
    if [ -n "$WEBHOOK" ]; then
        curl -s -X POST "$WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"Homelab Health Alert: $FAILED failures\n$(echo -e "$REPORT")\"}" >/dev/null
    fi
fi

exit $FAILED
