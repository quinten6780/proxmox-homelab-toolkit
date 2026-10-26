#!/bin/bash
# create-lxc.sh - Create an LXC container with best-practice defaults
# Usage: ./create-lxc.sh <CTID> <hostname> <ip> [template] [ram] [cores] [disk]

set -euo pipefail

CTID="${1:?Usage: $0 <CTID> <hostname> <ip> [template] [ram_mb] [cores] [disk_gb]}"
HOSTNAME="${2:?}"
IP="${3:?}"
TEMPLATE="${4:-debian-12-standard_12.2-1_amd64.tar.zst}"
RAM="${5:-512}"
CORES="${6:-1}"
DISK="${7:-8}"
GATEWAY="${GATEWAY:-192.168.1.1}"
BRIDGE="${BRIDGE:-vmbr0}"
STORAGE="${STORAGE:-local-lvm}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Creating LXC container $CTID ($HOSTNAME)...${NC}"

# Check if CTID already exists
if pct status "$CTID" &>/dev/null; then
    echo -e "${RED}Container $CTID already exists!${NC}"
    exit 1
fi

# Download template if not present
if ! pveam list local | grep -q "$TEMPLATE"; then
    echo -e "${YELLOW}Downloading template $TEMPLATE...${NC}"
    pveam download local "$TEMPLATE"
fi

# Create container
pct create "$CTID" "local:vztmpl/$TEMPLATE" \
    --hostname "$HOSTNAME" \
    --memory "$RAM" \
    --cores "$CORES" \
    --rootfs "$STORAGE:$DISK" \
    --net0 "name=eth0,bridge=$BRIDGE,ip=$IP/24,gw=$GATEWAY" \
    --unprivileged 1 \
    --features "nesting=1" \
    --onboot 1 \
    --start 1

echo -e "${GREEN}Container $CTID created and started.${NC}"
echo "  Hostname: $HOSTNAME"
echo "  IP: $IP"
echo "  RAM: ${RAM}MB"
echo "  Cores: $CORES"
echo "  Disk: ${DISK}GB"
echo ""
echo "Next steps:"
echo "  pct exec $CTID -- bash"
echo "  pct exec $CTID -- apt update && apt upgrade -y"
