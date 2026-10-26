---
title: "Proxmox Home Lab: From Zero to Production in One Weekend"
published: false
description: "Complete guide to building a production-grade home lab with Proxmox VE. Includes automation scripts, monitoring, backups, and security hardening."
tags: proxmox, homelab, selfhosted, devops
---

# Proxmox Home Lab: From Zero to Production in One Weekend

I've been running a Proxmox home lab for over a year now. What started as "let me try this on an old PC" turned into a 3-node cluster running 11 LXC containers, automated backups, monitoring that pages me at 3 AM, and GPU passthrough for local AI inference.

This is the guide I wish I had when I started.

## Why Proxmox?

Three reasons:

1. **It's free.** No licensing fees, no feature gates. The "enterprise" repo just provides update notifications.
2. **LXC containers.** Lighter than VMs, boot in seconds, near-native performance. Perfect for self-hosted services.
3. **ZFS built-in.** Snapshots, compression, and data integrity without extra software.

## Hardware: What You Actually Need

Forget the "you need a server" myth. Here's what works:

| Tier | Hardware | Cost | Containers |
|------|----------|------|------------|
| Starter | Intel NUC / mini PC (i5, 8GB, 256GB SSD) | $100-200 | 4-6 |
| Homelabber | Dell OptiPlex (i7, 16-32GB, 512GB SSD + 2TB HDD) | $300-500 | 10-15 |
| Production | 3x mini PCs, 32GB+ each, ZFS | $800+ | 30+ |

I run Tier 2. It handles everything I throw at it.

## The Setup

### 1. Install Proxmox

Download the ISO, flash to USB, boot. The installer is straightforward. Three tips:

- **Use a static IP.** DHCP reservations work but static is cleaner.
- **Separate OS and VM storage.** 32GB for Proxmox, rest for containers.
- **Remove the enterprise repo** if you don't have a subscription:

```bash
rm /etc/apt/sources.list.d/pve-enterprise.list
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
apt update
```

### 2. Create Your First Container

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

That's it. Container 100 is running in about 10 seconds.

### 3. Core Services Stack

Here's what I run and in what order:

1. **DNS (AdGuard Home)** — Block ads network-wide, resolve local hostnames
2. **Traefik** — Reverse proxy with automatic HTTPS
3. **Monitoring (Grafana + Prometheus)** — Know when things break
4. **Backups (PBS)** — Because "I'll back up later" means "I'll lose data"

### 4. The Automation That Saves Hours

I wrote scripts for everything repetitive:

**Create LXC with one command:**
```bash
./create-lxc.sh 101 traefik 192.168.1.12 debian-12-standard 256 1 4
```

**Backup everything:**
```bash
./backup-all.sh --storage local --keep 7
```

**Health check with alerts:**
```bash
./health-check.sh --email admin@example.com
```

All scripts are available in my [GitHub repo](https://github.com/quinten6780/proxmox-homelab-toolkit).

### 5. Security Hardening

Non-negotiable items:

- **SSH key auth only.** Passwords are for people who enjoy being hacked.
- **UFW firewall.** Default deny incoming, allow only what you need.
- **Fail2ban.** Ban IPs after 3 failed attempts.
- **Unprivileged containers.** Always. No exceptions.

```bash
# Quick SSH hardening
./harden-ssh.sh
```

### 6. Monitoring That Actually Helps

Prometheus scrapes metrics, Grafana displays them. The key dashboards:

- **Node Exporter Full** (ID: 1860) — CPU, RAM, disk, network
- **Proxmox VE** (ID: 10048) — VM/container metrics

Alerting rules that matter:
- Disk > 90% full
- Container down for > 1 minute
- CPU > 90% for 5 minutes

### 7. Backups: The Part Everyone Skips

Automated daily backups with 7-day retention. Test restores monthly. I learned this the hard way.

```bash
# Cron: daily backup at 2 AM
0 2 * * * root /opt/scripts/backup-all.sh >> /var/log/backup.log 2>&1
```

## What I'd Do Differently

1. **Start with ZFS.** Converting later is painful.
2. **Use a dedicated backup node.** PBS on the same machine defeats the purpose.
3. **Document as you go.** Future you will thank present you.

## Resources

- [Proxmox Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [My GitHub repo with all scripts](https://github.com/quinten6780/proxmox-homelab-toolkit)
- [r/Proxmox](https://reddit.com/r/Proxmox) — Great community

---

*Got questions? Drop them in the comments. I respond to all of them.*
