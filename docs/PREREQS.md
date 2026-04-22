# Prerequisites — fill before Phase 1

Copy values into your shell or into `.env` / `scripts/lxc.env` as you complete each step.


| Item                       | Your value | Notes                                                           |
| -------------------------- | ---------- | --------------------------------------------------------------- |
| LXC static IPv4            |            | Must not conflict with other LXCs/VMs/DHCP                      |
| Gateway                    |            | Often `192.168.1.1`                                             |
| Pi-hole DNS IP             |            | For LXC `dns-nameservers`                                       |
| Alienware / LM Studio IP   |            | Ports 1234 (chat), 1235 (embeddings)                            |
| Unused Proxmox CT ID       |            | `pct list` on host; doc example `200`                           |
| Ubuntu 24.04 template      |            | `pveam available | grep ubuntu-24.04` → full `local:vztmpl/...` |
| Proxmox storage for rootfs |            | e.g. `local-lvm`                                                |
| LAN CIDR for UFW           |            | e.g. `192.168.1.0/24`                                           |


## Commands to discover template

On Proxmox host:

```bash
pveam update
pveam available | grep ubuntu-24.04
```

## Pi-hole (after LXC has its IP)

Local DNS → DNS Records:

- `memory-engine.dev-path.org` → LXC IP
- `lmstudio.dev-path.org` → Alienware IP (when LM Studio is ready)

