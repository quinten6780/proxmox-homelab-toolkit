#!/bin/bash
# backup-all.sh - Automated backup of all LXC containers and VMs
# Usage: ./backup-all.sh [--storage STORAGE] [--keep DAYS] [--notify EMAIL]

set -euo pipefail

STORAGE="${STORAGE:-local}"
KEEP_DAYS="${KEEP_DAYS:-7}"
NOTIFY_EMAIL="${NOTIFY_EMAIL:-}"
LOG_FILE="/var/log/proxmox-backup.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "${GREEN}=== Proxmox Backup Started ===${NC}"

FAILED=0
BACKED_UP=0

# Backup all containers
log "Backing up LXC containers..."
for ct in $(pct list | awk 'NR>1 {print $1}'); do
    name=$(pct config "$ct" | grep hostname | cut -d: -f2 | tr -d ' ')
    log "  Backing up container $ct ($name)..."
    if vzdump "$ct" --storage "$STORAGE" --mode snapshot --compress zstd --quiet 2>>"$LOG_FILE"; then
        log "  ✓ Container $ct backed up"
        ((BACKED_UP++))
    else
        log "  ✗ Container $ct FAILED"
        ((FAILED++))
    fi
done

# Backup all VMs
log "Backing up VMs..."
for vm in $(qm list | awk 'NR>1 {print $1}'); do
    name=$(qm config "$vm" | grep name | cut -d: -f2 | tr -d ' ')
    log "  Backing up VM $vm ($name)..."
    if vzdump "$vm" --storage "$STORAGE" --mode snapshot --compress zstd --quiet 2>>"$LOG_FILE"; then
        log "  ✓ VM $vm backed up"
        ((BACKED_UP++))
    else
        log "  ✗ VM $vm FAILED"
        ((FAILED++))
    fi
done

# Clean old backups
log "Cleaning backups older than $KEEP_DAYS days..."
find /var/lib/vz/dump -name "vzdump-*.zst" -mtime +"$KEEP_DAYS" -delete 2>/dev/null || true

# Report
log "${GREEN}=== Backup Complete ===${NC}"
log "  Backed up: $BACKED_UP"
log "  Failed: $FAILED"

# Notify if configured
if [ -n "$NOTIFY_EMAIL" ] && [ $FAILED -gt 0 ]; then
    echo "Backup completed with $FAILED failures. Check $LOG_FILE" | \
        mail -s "Proxmox Backup Alert" "$NOTIFY_EMAIL"
fi

exit $FAILED
