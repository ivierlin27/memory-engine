#!/usr/bin/env bash
# Run on LXC once SSH from LAN works. Adjust LAN_CIDR to your network.
set -euo pipefail
LAN_CIDR="${LAN_CIDR:-192.168.1.0/24}"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow from "${LAN_CIDR}" to any
ufw --force enable
ufw status
