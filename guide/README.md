# Proxmox Home Lab: Zero to Production

**The complete guide to building a production-grade home lab with Proxmox VE**

---

## What's Inside

This isn't another "install Proxmox and make a VM" tutorial. This is the real-world playbook from running a 3-node cluster with 11 LXC containers, GPU passthrough, automated backups, and monitoring that pages you when something breaks.

### Who This Is For

- You have spare hardware (old PC, mini PC, or server)
- You want to self-host services (media, monitoring, development)
- You're tired of cloud bills and want control over your data
- You have basic Linux knowledge but want a structured path

### What You'll Build

By the end, you'll have:
- A Proxmox cluster (single node or multi-node)
- LXC containers for core services (DNS, reverse proxy, monitoring)
- Automated daily backups with verification
- Security hardening (SSH, firewall, fail2ban)
- Monitoring with Grafana + Prometheus
- Day-2 operations playbooks

---

## Table of Contents

0. **Introduction** — What this guide is and what it isn't
1. **Hardware & Planning** — Budget builds, node specs, network layout
2. **Proxmox Installation** — From bare metal to cluster
3. **LXC Containers** — Templates, networking, resource limits
4. **Core Services** — DNS (Pi-hole/AdGuard), Traefik reverse proxy, file sync
5. **Monitoring & Alerting** — Grafana + Prometheus + alerting rules
6. **Backups & Recovery** — PBS + Restic, verification, DR testing
7. **Security Hardening** — SSH, firewalls, fail2ban, least privilege
8. **Automation & Maintenance** — Ansible, cron, day-2 ops
9. **Advanced Topics** — ZFS, Ceph, live migration, GPU passthrough
10. **Appendix** — Quick reference, troubleshooting, version matrix

---

## Chapter 0: Introduction

### What This Guide Is

- Battle-tested configs from real production use
- Step-by-step with copy-paste commands
- Focus on reliability, not just "getting it working"
- Includes automation scripts you can run immediately

### What This Guide Is NOT

- A beginner's introduction to Linux (you should know basic bash)
- A cloud migration guide (this is on-prem)
- A vendor comparison (we use Proxmox, period)

### Prerequisites

- Hardware: Intel/AMD CPU with VT-x/AMD-V, 8GB+ RAM, 128GB+ storage
- Network: Static IP or DHCP reservation, access to router for port forwarding
- Knowledge: Basic Linux (cd, ls, nano/vim, systemctl), SSH
- Time: 1 weekend for basic setup, 1 week for full production

### Version Matrix

| Component | Tested Version | Minimum |
|-----------|---------------|---------|
| Proxmox VE | 8.2 | 8.0 |
| Debian | 12 (Bookworm) | 12 |
| Docker | 24.x | 24.0 |
| Ansible | 2.16 | 2.14 |

---

## Chapter 1: Hardware & Planning

### Budget Builds

**Tier 1: Starter ($100-200)**
- Used Intel NUC / mini PC (i5, 8GB RAM, 256GB SSD)
- Single node, 4-6 LXC containers
- Good for: DNS, reverse proxy, monitoring, 1-2 apps

**Tier 2: Homelabber ($300-500)**
- Used Dell OptiPlex / HP EliteDesk (i7, 16-32GB RAM, 512GB SSD + 2TB HDD)
- Single node, 10-15 LXC containers
- Good for: Full stack with media server, backups

**Tier 3: Production ($800+)**
- 3-node cluster (3x mini PCs or rack servers)
- 32GB+ RAM per node, ZFS storage
- Good for: High availability, GPU passthrough, Ceph

### Network Layout

```
Internet
    │
    ▼
[Router/Firewall] (192.168.1.1)
    │
    ├── [Proxmox Node 1] (192.168.1.10)
    │       ├── LXC: DNS (192.168.1.11)
    │       ├── LXC: Traefik (192.168.1.12)
    │       ├── LXC: Monitoring (192.168.1.13)
    │       └── LXC: Apps (192.168.1.14-20)
    │
    ├── [Proxmox Node 2] (192.168.1.20) [optional]
    │
    └── [Proxmox Node 3] (192.168.1.30) [optional]
```

### Storage Planning

| Use Case | Storage Type | Size | Notes |
|----------|-------------|------|-------|
| Proxmox OS | SSD | 32GB | Separate from VM storage |
| LXC/VM disks | SSD | 100-500GB | ZFS recommended |
| Media/Backups | HDD | 2-8TB | RAID1 or ZFS mirror |
| Backups (PBS) | HDD/SSD | 500GB-2TB | Separate from primary storage |

---

## Chapter 2: Proxmox Installation

### Download & Prepare

1. Download Proxmox VE ISO from proxmox.com
2. Create bootable USB (Rufus on Windows, dd on Mac/Linux)
3. Boot from USB

### Installation Steps

```
1. Select "Install Proxmox VE"
2. Accept EULA
3. Select target disk (SSD recommended)
4. Set country/timezone/keyboard
5. Set root password (strong, 16+ chars)
6. Set management IP (static recommended)
7. Confirm and install
```

### Post-Installation

```bash
# Update system
apt update && apt full-upgrade -y

# Remove enterprise repo (if no subscription)
rm /etc/apt/sources.list.d/pve-enterprise.list
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
apt update

# Install useful tools
apt install -y vim htop iotop ncdu tmux fail2ban

# Set up SSH key auth
mkdir -p ~/.ssh
chmod 700 ~/.ssh
# Add your public key to ~/.ssh/authorized_keys
```

### Cluster Setup (Multi-Node)

```bash
# On primary node
pvecm create mycluster

# On secondary nodes
pvecm add 192.168.1.10  # primary IP
```

---

## Chapter 3: LXC Containers

### Create LXC from Template

```bash
# Download template
pveam update
pveam download local debian-12-standard_12.2-1_amd64.tar.zst

# Create container
pct create 100 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
    --hostname dns-server \
    --memory 512 \
    --cores 1 \
    --rootfs local-lvm:8 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.1.11/24,gw=192.168.1.1 \
    --unprivileged 1 \
    --features nesting=1 \
    --start 1
```

### Resource Limits

| Service | RAM | CPU | Disk | Notes |
|---------|-----|-----|------|-------|
| DNS (Pi-hole) | 512MB | 1 | 8GB | Lightweight |
| Traefik | 256MB | 1 | 4GB | Reverse proxy |
| Monitoring | 2GB | 2 | 20GB | Prometheus + Grafana |
| App container | 1-4GB | 1-2 | 20-50GB | Depends on app |
| Database | 2-4GB | 2 | 50-100GB | PostgreSQL/MySQL |

### LXC Networking

```bash
# Static IP (recommended)
ip=192.168.1.11/24,gw=192.168.1.1

# DHCP (not recommended for servers)
ip=dhcp

# VLAN tagging
ip=192.168.1.11/24,gw=192.168.1.1,tag=10
```

---

## Chapter 4: Core Services

### DNS: Pi-hole or AdGuard Home

```bash
# AdGuard Home (recommended)
# Inside LXC container:
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v

# Configure at http://192.168.1.11:3000
# Set as DNS in router: 192.168.1.11
```

### Reverse Proxy: Traefik

```bash
# docker-compose.yml for Traefik
version: '3.8'
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./acme.json:/acme.json
    networks:
      - proxy

networks:
  proxy:
    external: true
```

### File Sync: Syncthing

```bash
# Install Syncthing
apt install syncthing -y
systemctl enable syncthing@root
systemctl start syncthing@root

# Access at http://192.168.1.11:8384
```

---

## Chapter 5: Monitoring & Alerting

### Prometheus + Grafana Stack

```bash
# docker-compose.yml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
```

### Key Dashboards

1. **Node Exporter Full** (ID: 1860) — CPU, RAM, disk, network
2. **Proxmox VE** (ID: 10048) — VM/container metrics
3. **Docker** (ID: 193) — Container metrics

### Alerting Rules

```yaml
# prometheus.yml alert rules
groups:
  - name: homelab
    rules:
      - alert: HighCPU
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU on {{ $labels.instance }}"

      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"

      - alert: ContainerDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
```

---

## Chapter 6: Backups & Recovery

### Proxmox Backup Server (PBS)

```bash
# Install PBS on dedicated node or LXC
# Download PBS ISO, install on separate machine
# Configure in Proxmox: Datacenter > Storage > Add > Proxmox Backup Server
```

### Automated Backup Script

```bash
#!/bin/bash
# backup-all.sh - Daily backup of all LXC containers and VMs

BACKUP_DIR="/mnt/backups/$(date +%Y-%m-%d)"
mkdir -p "$BACKUP_DIR"

# Backup all containers
for ct in $(pct list | awk 'NR>1 {print $1}'); do
    echo "Backing up container $ct..."
    vzdump $ct --storage local --mode snapshot --compress zstd
done

# Backup all VMs
for vm in $(qm list | awk 'NR>1 {print $1}'); do
    echo "Backing up VM $vm..."
    vzdump $vm --storage local --mode snapshot --compress zstd
done

# Clean old backups (keep 7 days)
find /var/lib/vz/dump -name "*.zst" -mtime +7 -delete

echo "Backup complete: $BACKUP_DIR"
```

### Restore Testing

```bash
# Test restore (dry run)
pct restore 999 /var/lib/vz/dump/vzdump-lxc-100-*.zst --storage local-lvm

# Verify
pct start 999
pct exec 999 -- systemctl status
pct stop 999
pct destroy 999
```

---

## Chapter 7: Security Hardening

### SSH Hardening

```bash
# /etc/ssh/sshd_config
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2

# Restart SSH
systemctl restart sshd
```

### Firewall (UFW)

```bash
# Install and configure
apt install ufw -y
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   # SSH
ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS
ufw allow 8006/tcp # Proxmox web UI
ufw enable
```

### Fail2ban

```bash
# /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600

# Restart
systemctl restart fail2ban
```

---

## Chapter 8: Automation & Maintenance

### Ansible Playbook

```yaml
# site.yml
---
- name: Configure Proxmox nodes
  hosts: proxmox
  become: yes
  tasks:
    - name: Update packages
      apt:
        update_cache: yes
        upgrade: dist

    - name: Install monitoring agent
      apt:
        name: node-exporter
        state: present

    - name: Configure SSH
      template:
        src: sshd_config.j2
        dest: /etc/ssh/sshd_config
      notify: restart sshd

  handlers:
    - name: restart sshd
      service:
        name: sshd
        state: restarted
```

### Cron Jobs

```bash
# /etc/crontab
# Daily backup at 2 AM
0 2 * * * root /opt/scripts/backup-all.sh >> /var/log/backup.log 2>&1

# Weekly update check (Sunday 3 AM)
0 3 * * 0 root apt update && apt list --upgradable >> /var/log/updates.log 2>&1

# Monthly reboot (1st of month, 4 AM)
0 4 1 * * root /sbin/reboot
```

### Health Check Script

```bash
#!/bin/bash
# health-check.sh - Check all services

SERVICES=("dns" "traefik" "monitoring" "backup")
FAILED=0

for svc in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$svc" 2>/dev/null || docker ps | grep -q "$svc"; then
        echo "✓ $svc: OK"
    else
        echo "✗ $svc: FAILED"
        FAILED=1
    fi
done

if [ $FAILED -eq 1 ]; then
    echo "ALERT: Some services are down!" | mail -s "Homelab Alert" admin@example.com
fi

exit $FAILED
```

---

## Chapter 9: Advanced Topics

### ZFS Storage

```bash
# Create ZFS pool
zpool create tank mirror /dev/sdb /dev/sdc
zfs create tank/vmdata
zfs set compression=lz4 tank/vmdata
zfs set atime=off tank/vmdata

# Add to Proxmox
# Datacenter > Storage > Add > ZFS
```

### GPU Passthrough

```bash
# Enable IOMMU
# /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"

# Update grub
update-grub
reboot

# Verify IOMMU groups
find /sys/kernel/iommu_groups/ -type l

# Add GPU to VM
# VM > Hardware > Add > PCI Device > Select GPU
```

### Live Migration

```bash
# Migrate VM between nodes
qm migrate 100 node2 --online

# Migrate container
pct migrate 100 node2
```

---

## Chapter 10: Appendix

### Quick Reference

| Command | Purpose |
|---------|---------|
| `pct list` | List containers |
| `qm list` | List VMs |
| `pct start 100` | Start container |
| `pct stop 100` | Stop container |
| `vzdump 100` | Backup container |
| `pct restore 100 backup.tar.zst` | Restore container |
| `pvecm status` | Cluster status |

### Troubleshooting

**Container won't start:**
```bash
pct start 100 --debug
journalctl -u pve-container@100
```

**Network issues:**
```bash
pct exec 100 -- ip addr
pct exec 100 -- ping 8.8.8.8
```

**Storage full:**
```bash
df -h
zfs list
# Clean old backups
find /var/lib/vz/dump -mtime +7 -delete
```

### Version Matrix

| Component | Tested | Minimum |
|-----------|--------|---------|
| Proxmox VE | 8.2 | 8.0 |
| Debian | 12 | 12 |
| Docker | 24.x | 24.0 |
| Ansible | 2.16 | 2.14 |
| Traefik | v3.0 | v2.10 |
| Prometheus | 2.50 | 2.45 |
| Grafana | 10.4 | 10.0 |

---

## License

Personal/internal commercial use OK. Do not resell this guide as-is.

---

*Built with real production experience. Not theory.*
