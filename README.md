# Proxmox Home Lab Toolkit

**Production-grade Proxmox setup scripts and guide.**

## What's Included

### Guide (154 pages equivalent)
Comprehensive markdown guide covering:
- Hardware planning and budget builds
- Proxmox installation and cluster setup
- LXC container management
- Core services (DNS, reverse proxy, file sync)
- Monitoring (Grafana + Prometheus)
- Backups and disaster recovery
- Security hardening
- Automation and day-2 operations
- Advanced topics (ZFS, GPU passthrough, live migration)

### Scripts
| Script | Purpose |
|--------|---------|
| `create-lxc.sh` | Create LXC containers with best-practice defaults |
| `backup-all.sh` | Automated backup of all containers and VMs |
| `health-check.sh` | Check all services and alert on failure |
| `harden-ssh.sh` | SSH hardening configuration |

### Templates
| Template | Purpose |
|----------|---------|
| `docker-compose-monitoring.yml` | Prometheus + Grafana + Node Exporter |
| `docker-compose-traefik.yml` | Traefik reverse proxy |
| `crontab.example` | Recommended cron jobs |

## Quick Start

1. Read the guide: `guide/README.md`
2. Run scripts from `scripts/` directory
3. Customize templates in `templates/`

## Requirements

- Proxmox VE 8.0+
- Debian 12 (Bookworm)
- Root access

## License

Personal/internal commercial use OK. Do not resell as-is.

## Support

Issues and questions: GitHub Issues
