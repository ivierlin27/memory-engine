#!/usr/bin/env bash
# Run ON the Proxmox host (e.g. ssh root@proxmox.dev-path.org) after copying this repo
# or pasting the script. Requires: lxc.env next to this script (copy from lxc.env.example).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lxc.env"

echo "Creating CT ${CT_ID} (${CT_HOSTNAME})..."

pct create "${CT_ID}" "${UBUNTU_TEMPLATE}" \
  --hostname "${CT_HOSTNAME}" \
  --cores "${CT_CORES}" \
  --memory "${CT_MEMORY_MB}" \
  --swap "${CT_SWAP_MB}" \
  --rootfs "${CT_STORAGE}:${CT_DISK_GB}" \
  --net0 "name=eth0,bridge=${CT_BRIDGE},ip=dhcp" \
  --features nesting=1 \
  --unprivileged 1 \
  --onboot 1 \
  --start 1

pct status "${CT_ID}"

echo "Applying static network inside CT (ifupdown style from MEMORY_ENGINE_BUILD_PLAN_v2)..."
echo "If Ubuntu 24.04 guest uses netplan instead, configure static IP manually."

pct exec "${CT_ID}" -- bash -s <<EOF
set -e
cat > /etc/network/interfaces <<'INET'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
  address ${LXC_IP}
  netmask ${LXC_NETMASK}
  gateway ${LXC_GATEWAY}
  dns-nameservers ${PIHOLE_DNS_IP}
INET
systemctl restart networking || true
EOF

echo "Installing base packages and Docker..."
pct exec "${CT_ID}" -- bash -c "
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get upgrade -y
apt-get install -y curl git htop jq sqlite3 python3-pip ufw rsync ca-certificates
curl -fsSL https://get.docker.com | sh
systemctl enable docker && systemctl start docker
apt-get install -y docker-compose-plugin
docker --version
docker compose version
mkdir -p /opt/memory-engine
"

echo "Done. Set Pi-hole DNS: memory-engine.dev-path.org -> ${LXC_IP}"
echo "Then from Mac: rsync project to root@${LXC_IP}:/opt/memory-engine/"
