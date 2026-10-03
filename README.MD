# Caddy + Cloudflare + CrowdSec (Docker)

A Caddy web server image with four extras baked in:

- **Docker Proxy** ([caddy-docker-proxy](https://github.com/lucaslorentz/caddy-docker-proxy/)) — auto-route to your Docker containers from their labels.
- **Cloudflare Trusted IP** — see real visitor IPs behind Cloudflare.
- **Cloudflare DNS** — automatic HTTPS certificates through Cloudflare.
- **CrowdSec Bouncer** — block bad traffic before it reaches your site.

## What you need

- Docker with Docker Compose
- A domain pointed at your server's IP
- A Cloudflare account (for DNS + an API token)

## Setup

Do these in order. CrowdSec and Cloudflare DNS are optional — skip those steps if you don't want them.

### 1. Create a project folder

```bash
mkdir caddy && cd caddy
```

### 2. Create the `.env` file

```env
DOMAIN=example.com
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token
CROWDSEC_API_KEY=your_crowdsec_bouncer_key
```

- `DOMAIN` — your domain name.
- `CLOUDFLARE_API_TOKEN` — from **Cloudflare → My Profile → API Tokens**. Needs *Zone → DNS → Edit* permission.
- `CROWDSEC_API_KEY` — only needed for CrowdSec (see below). Leave it empty if you're skipping CrowdSec.

### 3. Create your `Caddyfile`

A minimal one to get started:

```caddyfile
example.com {
    respond "Hello!"
}
```

> Replace `example.com` with your actual domain.

### 4. Create `docker-compose.yml`

Copy the compose file from [the section below](#the-compose-file).

### 5. Create the network

```bash
docker network create frontend
```

### 6. Create the data directories

The image runs as a non-root user, so it can't create these folders itself.
Make them first and hand them over:

```bash
mkdir -p app_data/srv app_data/acme app_data/logs app_data/crowdsec/db
sudo chown -R 65532:65532 app_data
```

### 7. Start it

```bash
docker compose up -d
```

### 8. Check it's working

```bash
docker compose logs -tf
```

Open `https://example.com` in your browser. Caddy gets its certificate automatically.

## The compose file

```yaml
services:

  crowdsec:
    image: crowdsecurity/crowdsec
    container_name: crowdsec
    restart: unless-stopped
    networks:
      - frontend
    environment:
      - GID=1000
      - COLLECTIONS=crowdsecurity/linux crowdsecurity/caddy crowdsecurity/appsec-generic-rules crowdsecurity/appsec-virtual-patching crowdsecurity/http-cve crowdsecurity/whitelist-good-actors
      - BOUNCER_KEY_CADDY=${CROWDSEC_API_KEY}
    volumes:
      - ./app_data/crowdsec/acquis.yaml:/etc/crowdsec/acquis.yaml
      - ./app_data/crowdsec:/etc/crowdsec
      - ./app_data/crowdsec/db:/var/lib/crowdsec/data
      - ./app_data/logs:/var/log/caddy:ro

  caddy:
    image: starkayc/caddy:latest
    container_name: caddy
    restart: unless-stopped
    networks:
      - frontend
    environment:
      - DOMAIN
      - CLOUDFLARE_API_TOKEN
      - CROWDSEC_API_KEY
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"  # HTTP/3
    cap_add:
      - NET_BIND_SERVICE  # see the note under this compose file
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./app_data/srv:/srv
      - ./app_data/acme:/data
      - ./app_data/logs:/var/log/caddy

networks:
  frontend:
    external: true
```

> Not using CrowdSec? Delete the whole `crowdsec:` block above.

> You don't actually need that `cap_add` line. Docker already lets the non-root
> user bind ports 80 and 443. It's harmless, and it helps if you ever run this
> image somewhere stricter, like Kubernetes.

## Optional: Cloudflare DNS

If you want Caddy to issue certificates through Cloudflare (so it can do DNS-01 challenges), add this to your `Caddyfile`:

```caddyfile
tls {
    dns cloudflare {env.CLOUDFLARE_API_TOKEN}
}
```

## Optional: CrowdSec

**Step 1 — get the bouncer key:**

```bash
docker compose up -d crowdsec
docker compose exec crowdsec cscli bouncers add caddy-bouncer
```

Copy the key it prints into `.env` (`CROWDSEC_API_KEY`).

**Step 2 — add CrowdSec to your `Caddyfile`:**

```caddyfile
{
    admin off
    servers {
        trusted_proxies cloudflare
        client_ip_headers Cf-Connecting-Ip X-Forwarded-For
    }
    order crowdsec before respond
    crowdsec {
        api_url http://crowdsec:8080
        api_key <your_bouncer_key>
        ticker_interval 5s
        appsec_url http://crowdsec:7422
    }
}

example.com {
    crowdsec
    respond "Hello!"
}
```

Then restart: `docker compose up -d`.
