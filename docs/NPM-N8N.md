# Nginx Proxy Manager → n8n

## Facts

| URL | Expected |
|-----|----------|
| `http://192.168.x.x:5678` | Works — plain HTTP to the n8n container |
| `https://192.168.x.x:5678` | **Fails** — n8n does not terminate TLS on that port |
| `https://n8n.dev-path.org` | Correct — NPM terminates HTTPS and proxies **HTTP** to the LXC |

Use **`http://`** for Scheme **→** **Forward** to `192.168.1.69:5678` (your LXC IP).

## NPM Proxy Host

- **Domain:** `n8n.dev-path.org`
- **Scheme:** `http`
- **Forward hostname / IP:** your n8n LXC (e.g. `192.168.1.69`)
- **Forward port:** `5678`
- **Websockets:** ON
- **SSL:** Let’s Encrypt on **this** proxy host (HTTPS on 443 for the domain)

Advanced / Custom Nginx (only if you see **421** or odd HTTP/2 behaviour): try disabling HTTP/2 for this host (depends on NPM version — some expose “HTTP/2” or you add a snippet to prefer HTTP/1.1).

## n8n env (compose)

`N8N_PROTOCOL=https`, `WEBHOOK_URL`, `N8N_EDITOR_BASE_URL`, and `N8N_PROXY_HOPS=1` tell n8n the **public** URL is HTTPS while the connection from NPM is HTTP with `X-Forwarded-Proto`.

Restart n8n after changing env: `docker compose up -d n8n`.

## Browser messages

- **Secure cookie / insecure URL:** usually means you opened **`http://IP:5678`** while n8n expects **`https://n8n.dev-path.org`**. Use the domain through NPM, or temporarily set `N8N_SECURE_COOKIE=false` only for debugging (not recommended long term).

- **Safari:** if issues persist, try Chrome/Firefox; ensure you use **`https://n8n.dev-path.org`**, not raw IP over HTTPS.

## HTTP 421

Often **HTTP/2 + TLS** + multiple vhosts on the same NPM instance. Things to try: disable HTTP/2 for this proxy host; confirm **DNS** for `n8n.dev-path.org` points to the **NPM** host IP; confirm the SSL certificate includes **`n8n.dev-path.org`**.
