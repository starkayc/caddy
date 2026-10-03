ARG CADDY_VERSION=2.11.6
# Supplies the Go toolchain and xcaddy only; the build target is CADDY_VERSION
# below. Leave this at an older release until a build fails on a newer Go.
ARG CADDY_BUILDER_VERSION=2.11.6

FROM caddy:${CADDY_BUILDER_VERSION}-builder AS builder

ARG CADDY_VERSION

RUN xcaddy build v${CADDY_VERSION} \
	--with github.com/lucaslorentz/caddy-docker-proxy/v2 \
	--with github.com/caddy-dns/cloudflare \
	--with github.com/WeidiDeng/caddy-cloudflare-ip \
	--with github.com/hslatman/caddy-crowdsec-bouncer/http@main \
	--with github.com/hslatman/caddy-crowdsec-bouncer/layer4@main \
	--with github.com/hslatman/caddy-crowdsec-bouncer/appsec

FROM alpine:3.21 AS dirs

RUN mkdir -p /config/caddy /data/caddy /etc/caddy /srv /var/log/caddy \
	&& chown -R 65532:65532 /config /data /etc/caddy /srv /var/log/caddy

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY --from=dirs --chown=65532:65532 /config /config
COPY --from=dirs --chown=65532:65532 /data /data
COPY --from=dirs --chown=65532:65532 /etc/caddy /etc/caddy
COPY --from=dirs --chown=65532:65532 /srv /srv
COPY --from=dirs --chown=65532:65532 /var/log/caddy /var/log/caddy

ENV XDG_CONFIG_HOME=/config
ENV XDG_DATA_HOME=/data

EXPOSE 80
EXPOSE 443
EXPOSE 443/udp
EXPOSE 2019

WORKDIR /srv

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
