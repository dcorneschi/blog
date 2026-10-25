---
title: "ProxMenux Monitor: A Web Dashboard for Proxmox VE"
date: 2026-10-15T00:00:00+03:00
draft: false
description: "What ProxMenux Monitor is, how it runs on a Proxmox VE host, how to install and secure it, put it behind a reverse proxy, and use its Health Monitor, notifications and REST API with Prometheus, Homepage and Uptime Kuma."
tags: ["proxmox", "monitoring", "homelab"]
categories: ["devops"]
---

[ProxMenux](https://github.com/MacRimi/ProxMenux) is a menu-driven toolkit for Proxmox VE: post-install tweaks, backup and restore, hardware and storage helpers, all from a `menu` command on the host. Since version 1.1.7 (September 2025) it also ships **ProxMenux Monitor**, a web dashboard that runs on the Proxmox host itself and shows the host, its storage, network, VMs and containers in one place, with a health checker, notifications and a REST API on top.

This article covers the stable release **v1.2.6** (September 2026). The project moves fast (a v1.2.6.2 beta is already out), so check the [release notes](https://github.com/MacRimi/ProxMenux/releases) for newer changes. The behaviour described here was checked against the v1.2.6 source and by running the v1.2.6 AppImage: setup, login with 2FA, tokens, the API, Prometheus scraping and both reverse proxy configs.

## Key Takeaways

- ProxMenux Monitor is one process on the Proxmox host, started by `proxmenux-monitor.service`, listening on **TCP 8008** (IPv6 and IPv4) for both the dashboard and the API. Nothing is installed in the VMs or containers.
- It's installed together with ProxMenux by a one-line installer and needs Proxmox VE 8 or later.
- Authentication is **opt-in**: on first launch you choose between setting a password and leaving every endpoint open. Set the password, then add TOTP 2FA.
- It runs as **root**, and the dashboard includes a web terminal: whoever can log in has a root shell on the host. Keep port 8008 on the LAN or a VPN, and put a reverse proxy with HTTPS in front for anything else.
- The Health Monitor checks ten categories every 5 minutes and feeds notifications (Telegram, Discord, Email, Gotify, Pushover, Apprise); the REST API and a Prometheus endpoint feed Grafana, Homepage, Home Assistant and Uptime Kuma.

## What the Dashboard Shows

| Section | What it covers |
|---------|----------------|
| Overview | CPU, memory, temperature, uptime and the overall health state of the host |
| Health Monitor | Active and dismissed alerts in ten categories (CPU, memory, storage, disks, network, services, logs, VMs, updates, security) |
| Storage | Proxmox storage pools, physical disks (SATA, NVMe, USB), SMART attributes, ZFS pool state, disk wear |
| Network | Physical interfaces, bonds, bridges and OVS devices with addresses, state and RX/TX graphs |
| VMs & Containers | Every VM and LXC with status, resources and uptime; per-guest config, metrics, logs and start/stop/reboot actions |
| Hardware | CPU and memory layout, PCIe devices, GPUs with live usage (NVIDIA, Intel iGPU), IPMI sensors and UPS state |
| Logs & Events | The system journal with filters, Proxmox task history, notification history |
| Terminal | A browser shell (xterm.js over WebSocket) to the host or into a VM or container |
| Security | Failed logins and, when Fail2Ban is installed, jail status and bans |

The dashboard is responsive and can be added to a phone's home screen as a web app, but it still needs a connection to the host on port 8008.

## How It Runs

ProxMenux Monitor is shipped as an AppImage with its own Python libraries. It runs them with the host's `python3`, but doesn't install anything into the host's Python packages. The installer unpacks it under `/usr/local/share/proxmenux/` and registers `proxmenux-monitor.service`, which starts one Flask process as root:

- it listens on `[::]:8008`, which covers IPv6 and IPv4, serves the Next.js dashboard under `/` and the API under `/api/*`, and speaks plain HTTP unless [HTTPS is turned on](#built-in-https);
- it reads data with the same tools an admin would use: `psutil`, `pvesh`/`qm`/`pct`, `smartctl`, `zpool`, `journalctl`, `ip`, `nvidia-smi`, `lspci`, `dmidecode`, and the bundled `ipmitool`, `sensors` and `upsc`;
- expensive calls such as `smartctl -a` and `pvesh get` are cached for a few seconds to a few minutes, so an open dashboard doesn't hammer the disks;
- background jobs keep running with no browser open: a temperature and latency sample every minute, a full health check every 5 minutes, and watchers on the journal, the Proxmox task list and backup/replication hooks for notifications.

Root is required: SMART data, `pvesh`, the journal, ZFS commands and the terminal all need it.

The `[::]` socket needs IPv6 in the kernel. On a host booted with `ipv6.disable=1` the service doesn't start (`OSError: [Errno 97] Address family not supported by protocol`) and systemd restarts it every 10 seconds; disabling IPv6 with `sysctl` instead is fine.

Its state lives in two places, worth including in host backups:

| Path | Contents |
|------|----------|
| `/usr/local/share/proxmenux/health_monitor.db` | SQLite database: alerts, dismissals, disk history, notification settings and history |
| `/root/.config/proxmenux-monitor/auth.json` | Login: user, password hash, TOTP secret, backup codes, issued API tokens |

Notification secrets (bot tokens, webhook URLs, AI API keys, the mail password) are encrypted in the database with a key in `/usr/local/share/proxmenux/.notification_key`, and login events are written to `/var/log/proxmenux-auth.log`.

## Installing

ProxMenux needs **Proxmox VE 8 or later**, root on the host and internet access. The installer adds `dialog`, `curl`, `jq` and `git`, copies the scripts to `/usr/local/share/proxmenux/`, creates the `/usr/local/bin/menu` launcher and installs the Monitor service.

Read the installer before running it as root: [install_proxmenux.sh](https://github.com/MacRimi/ProxMenux/blob/main/install_proxmenux.sh). Then, on the Proxmox host:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/MacRimi/ProxMenux/main/install_proxmenux.sh)"
```

The beta channel, built from the `develop` branch, has its own installer:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/MacRimi/ProxMenux/develop/install_proxmenux_beta.sh)"
```

Afterwards, `menu` opens the text menus, and the dashboard is at `http://<proxmox-ip>:8008`. ProxMenux updates itself: the next `menu` run after a release offers the update. To remove everything, use **Settings → Uninstall ProxMenux** in the menu.

### Service Control

The Monitor is a normal systemd service:

```bash
systemctl status proxmenux-monitor.service
systemctl enable --now proxmenux-monitor.service     # start now and at boot
systemctl disable --now proxmenux-monitor.service    # stop and keep it off
journalctl -u proxmenux-monitor.service -f           # follow its log
systemctl cat proxmenux-monitor.service              # the unit the installer wrote
```

The unit runs as `User=root`, restarts on failure after 10 seconds, and sets `Environment="PORT=8008"`. v1.2.6 ignores that variable, though: the port is fixed at 8008 in the code, so an override with another `PORT` doesn't move it. To change settings without editing the installer's file, add an override with `systemctl edit proxmenux-monitor.service`, which survives reinstalls.

## First Launch and Authentication

The first visit shows a dialog, **Protect Your Dashboard?**, with two choices:

- **Yes, Setup Password** creates the admin account: a username, a password of at least 10 characters using three of lowercase, uppercase, digits and symbols, and optionally a display name and avatar.
- **No, Continue Without Protection** leaves every API endpoint open on port 8008. The dialog doesn't come back; authentication can be turned on later from the Security tab.

Two-factor authentication isn't part of that first choice: once logged in, enable **TOTP 2FA** from the Security tab. After that, login asks for the 6-digit code in a second step.

Two kinds of tokens exist:

| Token | Lifetime | Use |
|-------|----------|-----|
| Session token | 24 hours | Issued at login, used by the dashboard |
| API token | 365 days | For scripts and integrations; created in **Security → API Access Tokens** and shown only once |

Both are sent as `Authorization: Bearer <token>`. Logins are rate-limited by the Monitor itself: after 5 attempts from one address within 5 minutes it answers `Too many login attempts. Please wait and try again.` A forgotten password is reset from the menu, as root on the host: `menu` → **Settings → Reset ProxMenux Monitor Password**. It backs up `auth.json`, clears the user and 2FA but keeps the API tokens, and the setup wizard appears again on the next visit.

> **The terminal is a root shell.** The Monitor runs as root, so the web terminal gives anyone who logs in full control of the host. Always set a password and 2FA, and don't publish port 8008 to the internet.

## Built-in HTTPS

The Monitor can also serve HTTPS itself. In **Security → SSL / HTTPS**, choose **Use Proxmox certificate** (the host's `/etc/pve/local/pveproxy-ssl.pem` if you installed one, otherwise the self-signed `pve-ssl.pem`) or **Use custom certificate** with your own certificate and key paths. The service restarts and the dashboard moves to `https://<proxmox-ip>:8008`; the choice is stored in `/etc/proxmenux/ssl_config.json`. With the self-signed Proxmox certificate, browsers show a warning, as they do for the Proxmox web UI on port 8006.

## Behind a Reverse Proxy

For access from outside the LAN, put the Monitor behind a reverse proxy with HTTPS (or reach it over a VPN). The proxy must forward WebSocket upgrades, or the terminal tab won't connect. An Nginx server block:

```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name monitor.example.com;

    ssl_certificate     /etc/letsencrypt/live/monitor.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/monitor.example.com/privkey.pem;

    location / {
        proxy_pass         http://127.0.0.1:8008;
        proxy_http_version 1.1;

        # WebSocket upgrade for the terminal
        proxy_set_header   Upgrade           $http_upgrade;
        proxy_set_header   Connection        "upgrade";

        # Real client address for the auth log and Fail2Ban
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_set_header   X-Forwarded-Host  $host;
    }
}
```

`http2 on;` needs Nginx 1.25.1 or later; older versions use `listen 443 ssl http2;` instead (newer ones still accept it, with a deprecation warning). Without the two WebSocket lines the dashboard loads but the terminal doesn't connect. `proxy_pass http://127.0.0.1:8008` assumes Nginx runs on the Proxmox host; from another machine, use the host's address. Caddy handles WebSockets and forwarded headers by itself:

```text
monitor.example.com {
	reverse_proxy 127.0.0.1:8008
}
```

**Trust the proxy's headers.** In v1.2.6 the Monitor uses `X-Forwarded-For` and `X-Real-IP` only when the environment variable `PROXMENUX_TRUST_PROXY=1` is set; otherwise every request appears to come from the proxy's address, and the auth log and Fail2Ban see only that one IP. Set it with an override:

```bash
systemctl edit proxmenux-monitor.service
```

```ini
[Service]
Environment="PROXMENUX_TRUST_PROXY=1"
```

```bash
systemctl restart proxmenux-monitor.service
```

Only set it when a proxy you control is in front: on direct access, any client could send a fake `X-Forwarded-For` and dodge the per-IP ban.

**Fail2Ban** is optional and not installed by the Monitor. When it's installed with the `proxmenux` jail (from the **Security → Fail2Ban** menu in ProxMenux), the jail reads `/var/log/proxmenux-auth.log`, and the Monitor also refuses requests from banned addresses itself (HTTP 403), which matters behind a proxy where the firewall only ever sees the proxy.

## The Health Monitor

Every 5 minutes the Health Monitor runs one cycle over ten categories:

| Category | Checks |
|----------|--------|
| Services | `pveproxy`, `pvedaemon`, `pvestatd`, `pve-cluster` |
| Storage | Proxmox storage pools and their availability |
| Disks | SMART, I/O errors in the kernel log, ZFS pool health, filesystem usage |
| VMs | Failed starts, crashed guests, shutdown failures |
| Network | Bridge and bond state, link state, latency to the gateway |
| Updates | Pending package and security updates |
| Logs | Repeated errors and bursts in the system journal |
| Memory | OOM kills, sustained memory pressure |
| CPU | Sustained usage and CPU temperature against their thresholds |
| Security | Failed logins, bans, Fail2Ban jail state |

Each finding gets a severity (INFO, WARNING, CRITICAL) and a stable key, so a repeated problem updates one alert instead of creating new ones. Dismissing an alert silences it for the category's suppression time, 24 hours by default and configurable per category, but a real escalation (for example a temperature crossing the critical threshold) is reported anyway.

## Notifications and the AI Assistant

Health events, Proxmox tasks, backup and replication results and journal errors can be sent to **Telegram, Discord, Email, Gotify, Pushover** and **Apprise** (which reaches many more services). Each channel is configured separately, and categories can be turned off per channel.

An optional AI assistant can rewrite each notification in plain language and suggest next steps, with OpenAI, Anthropic, Gemini, Groq, OpenRouter or a local **Ollama**. It's off by default. With a cloud provider, the event text (host names, guest names, log lines) is sent to that provider; Ollama keeps it on your network.

## The REST API

Everything the dashboard shows is also available as JSON:

```bash
# A session token from the login endpoint (add "totp_token":"123456" when 2FA is on)
curl -X POST http://<proxmox-ip>:8008/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"<user>","password":"<password>"}'

# Data with a session or API token
curl -H "Authorization: Bearer <token>" http://<proxmox-ip>:8008/api/system
```

Some endpoints worth knowing:

| Endpoint | Returns |
|----------|---------|
| `/api/system` | CPU, memory, temperature, uptime and host details |
| `/api/storage`, `/api/proxmox-storage` | Disks and SMART data, Proxmox storage pools |
| `/api/network` | Interfaces and traffic |
| `/api/vms` | VMs and containers |
| `/api/logs` | Journal entries |
| `/api/prometheus` | Metrics in Prometheus format |
| `/api/system-info` | Hostname, uptime and health status, **without** a token |

`/api/system-info` is meant for uptime checks: it answers without authentication, so a status page or load balancer can probe the host without holding a token.

## Integrations

**Prometheus and Grafana.** Scrape `/api/prometheus` with an API token. The metrics are named `proxmox_*` (for example `proxmox_cpu_usage{node="pve01"}`):

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'proxmenux'
    metrics_path: /api/prometheus
    scheme: http                  # https when the Monitor is behind TLS
    scrape_interval: 30s
    authorization:
      type: Bearer
      credentials: '<api-token>'
    static_configs:
      - targets: ['pve01.lan:8008', 'pve02.lan:8008']
```

**Homepage.** A `customapi` widget reads `/api/system`:

```yaml
- ProxMenux Monitor:
    href: http://pve01.lan:8008/
    widget:
      type: customapi
      url: http://pve01.lan:8008/api/system
      headers:
        Authorization: Bearer <api-token>
      refreshInterval: 10000
      mappings:
        - field: cpu_usage
          label: CPU
          format: percent
        - field: memory_usage
          label: RAM
          format: percent
        - field: temperature
          label: Temp
          format: number
          suffix: °C
```

**Uptime Kuma** or any check script can use the token-free endpoint:

```bash
curl -s http://pve01.lan:8008/api/system-info | jq -e '.health.status == "healthy"'
```

`jq -e` exits non-zero when the expression is false, so the command fails whenever the host isn't reported healthy. For Home Assistant, the project's documentation has ready-made `rest:` sensors and dashboard cards built on the same endpoints.

## Security Checklist

- **Set a password on first launch** and enable 2FA; never pick "Continue Without Protection" on a network you don't fully control.
- **Keep port 8008 private.** Use the LAN, a VPN such as Tailscale or WireGuard, or a reverse proxy with HTTPS. Out of the box the Monitor speaks plain HTTP; turn on [built-in HTTPS](#built-in-https) at least.
- **Remember the terminal is root.** A stolen session is a full host compromise.
- **Treat API tokens like passwords.** They live 365 days; give each integration its own token and revoke unused ones in **Security → API Access Tokens**.
- **Behind a proxy**, set `PROXMENUX_TRUST_PROXY=1` so logins and bans see the real client address, and add Fail2Ban for brute-force protection.
- **Back up** `auth.json`, `health_monitor.db` and `.notification_key` together: tokens and dismissed alerts depend on the first two, and the notification secrets in the database can't be decrypted without the key.

## Links

- [ProxMenux on GitHub](https://github.com/MacRimi/ProxMenux)
- [ProxMenux releases](https://github.com/MacRimi/ProxMenux/releases)
