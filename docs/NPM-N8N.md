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

**421 Misdirected Request** usually comes from the **proxy + TLS + HTTP/2** stack, not from n8n.

Work through these on **Nginx Proxy Manager**:

1. **SSL tab (required for `https://n8n...`)**  
   - Turn on **SSL** with a certificate that covers **`n8n.dev-path.org`** (Let’s Encrypt).  
   - Enable **Force SSL** / **HTTP → HTTPS** if you want.  
   - Without a cert on **this** Proxy Host, HTTPS may hit the wrong default server and produce odd errors (including 421).

2. **HTTP/2**  
   Some setups fix 421 by **disabling HTTP/2** for this host only (depends on NPM version — look for an HTTP/2 toggle on the SSL tab or global NPM settings).  
   Alternatively add **Custom Nginx Configuration** (Advanced) if your NPM build supports it — avoid fighting the generated `listen` unless you know the template.

3. **DNS**  
   `n8n.dev-path.org` must resolve to the **NPM machine’s LAN IP**, not necessarily the n8n LXC IP.

4. **Clear browser state**  
   Try a **private window** or another browser after changing SSL — cached HTTP/2 / HSTS can confuse diagnosis.

5. **Sanity check from Mac**

```bash
curl -vk --resolve n8n.dev-path.org:443:<NPM_IP> https://n8n.dev-path.org/
```

Replace `<NPM_IP>` with the host that runs NPM. You should see **HTTP/2 or HTTP/1.1** and a valid cert for `n8n.dev-path.org`.

---

## Secure cookie warning on `http://192.168.1.69:5678`

That is **expected** while **`N8N_PROTOCOL=https`** (and cookies are “secure”). You are opening a **plain HTTP** URL.

**Recommended:** finish setup using **`https://n8n.dev-path.org`** only (after NPM SSL is correct).

**Temporary LAN debugging:** set in `.env`  
`N8N_SECURE_COOKIE=false`  
then `docker compose up -d n8n`. Do **not** leave this off on anything internet-exposed.
