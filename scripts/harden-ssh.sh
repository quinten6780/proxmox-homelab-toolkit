#!/bin/bash
# harden-ssh.sh - SSH hardening for Proxmox nodes
# Usage: ./harden-ssh.sh [--port PORT] [--allow-user USER]

set -euo pipefail

SSH_PORT="${SSH_PORT:-22}"
ALLOW_USER="${ALLOW_USER:-root}"

echo "Hardening SSH configuration..."

# Backup original
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d)

# Write hardened config
cat > /etc/ssh/sshd_config << 'EOF'
# Hardened SSH configuration
Port 22
Protocol 2

# Authentication
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
MaxAuthTries 3
MaxSessions 5

# Security
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitTunnel no
GatewayPorts no

# Timeouts
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 60

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Ciphers (modern, secure)
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org

# Allow specific user
AllowUsers root
EOF

# Validate config
if sshd -t; then
    systemctl restart sshd
    echo "SSH hardened and restarted successfully."
    echo "WARNING: Ensure you have SSH key access before disconnecting!"
else
    echo "ERROR: SSH config validation failed. Restoring backup."
    cp /etc/ssh/sshd_config.bak.* /etc/ssh/sshd_config
    exit 1
fi
