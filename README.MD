# Caddy Docker Image with Extra Modules

This Docker image contains an intentional minimalistic version of Caddy with additional modules for enhanced functionality. It has been built with a focus on security and simplicity. The official Caddy web server is used as the base image.

## Extra Modules Loaded
The following extra modules are loaded into this Caddy Docker Image:

1. **Cloudflare Trusted IP** - This module retrieves Cloudflare IPs from their official website, supporting IPv4 and IPv6. It is supported from Caddy v2.6.3 onwards. 

Example:
```caddyfile
trusted_proxies cloudflare {
    interval 12h
    timeout 15s
}
```

2. **Cloudflare DNS** - This package contains a DNS provider module for Caddy, allowing you to manage DNS records with Cloudflare accounts.

Example:
```caddyfile
tls {
    dns cloudflare {env.CF_API_TOKEN}
}
```

3. **CrowdSec Bouncer** - The CrowdSec Bouncer consists of the following five main pieces: A Caddy App, a Caddy Bouncer HTTP Handler, a Caddy Layer 4 Connection Matcher, a Caddy AppSec HTTP Handler and the caddy crowdsec command.

To enable CrowdSec, you would run the CrowdSec container, add the Caddy bouncer, generating an API key, copy and paste the API key in the `Caddyfile` file, then run Caddy.

Caddyfile:
```caddyfile

{
        admin off
        servers {
                trusted_proxies cloudflare
                client_ip_headers Cf-Connecting-Ip X-Forwarded-For
        }
        order crowdsec before respond
        crowdsec {
                api_url http://localhost:8080
                api_key <api_key>
                ticker_interval 5s
                appsec_url http://localhost:7422
        }
}

:80 {
        crowdsec
        respond /health-check 200
        respond "pong"
}
```
Generate API Key:
```bash
# Start CrowdSec container
$ docker compose up -d crowdsec

# Add the Caddy bouncer, generating an API key
$ docker compose exec crowdsec cscli bouncers add caddy-bouncer

# Start Caddy
$ docker compose up -d caddy

# Check the logs
$ docker compose logs -tf
```

## Usage
To use this image, you can either run the Caddy server manually or integrate it into your deployment pipeline. Here's an example of how you might run Caddy in a docker-compose file:

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
      - ./app_data/crowdsec/acquis.yaml:/etc/crowdsec/acquis.yaml # Acquis File
      - ./app_data/crowdsec:/etc/crowdsec # CrowdSec Data Directory
      - ./app_data/crowdsec/db:/var/lib/crowdsec/data # CrowdSec Database
      - ./app_data/logs:/var/log/caddy:ro # Caddy Logs

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
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile # Caddyfile
      - ./app_data/srv:/srv # Website Data Directory
      - ./app_data/acme:/data # Acme Data Directory
      - ./app_data/logs:/var/log/caddy # Caddy Logs
      
networks:
  frontend:
    external: true
```