# OneUptime app wrapper for Railway. Upstream ships one image for the dashboard, the API, the status pages and OTLP ingest (port 3002) and a
# separate nginx "ingress" image that only does TLS and routing, which Railway's edge already does. The stock app has no first-account story:
# the first person to reach the sign-up form becomes Master Admin. This image starts the app on a private port, creates that owner from
# ADMIN_EMAIL and ADMIN_PASSWORD, turns OneUptime's own "disable sign up" setting on, and only then opens ONE public port.
# upstream: OneUptime/oneuptime
# 17.1.0 is the newest release at build time (checked against the GitHub releases API on 2026-11-22).
FROM oneuptime/app:17.1.0@sha256:a1b5c57d6e5e431b384610baaa63c491ab38b541b1c0ba85b37ec0c7c0b6c294

# Baked so the deploy form stays empty: a literal template variable publishes as a blank required field.
# VALKEY_IP_FAMILY=0 lets ioredis resolve Railway's IPv6-first private names.
ENV HTTP_PROTOCOL=https \
    ENVIRONMENT=production \
    BILLING_ENABLED=false \
    DATABASE_PORT=5432 \
    VALKEY_USERNAME=default \
    VALKEY_PORT=6379 \
    VALKEY_DB=0 \
    VALKEY_IP_FAMILY=0 \
    CLICKHOUSE_PORT=8123 \
    CLICKHOUSE_MAX_OPEN_CONNECTIONS=100

COPY --chmod=0755 boot.sh /railway-boot.sh
COPY --chmod=0644 proxy.mjs /railway-proxy.mjs
COPY --chmod=0644 close-signup.cjs /usr/src/app/railway-close-signup.cjs

EXPOSE 8080
# Redefining ENTRYPOINT resets the base image CMD to empty, so the upstream CMD (heap sized to the cgroup, then node Index.js) is restated verbatim;
# boot.sh passes it to the stock docker-entrypoint.sh.
ENTRYPOINT ["/railway-boot.sh"]
CMD ["sh", "-c", "heap=8096; for file in \"/sys/fs/cgroup$(sed -n 's/^0:://p' /proc/self/cgroup 2>/dev/null)/memory.max\" /sys/fs/cgroup/memory.max /sys/fs/cgroup/memory/memory.limit_in_bytes; do limit=$(cat \"$file\" 2>/dev/null); case $limit in ''|*[!0-9]*|????????????????*) ;; *) heap=$((limit / 1048576 * 3 / 4)); [ $heap -ge 256 ] || heap=256; [ $heap -le 8096 ] || heap=8096; break ;; esac; done; export NODE_OPTIONS=\"--max-old-space-size=$heap${NODE_OPTIONS:+ $NODE_OPTIONS}\" && exec node --no-node-snapshot --require Common/Server/Utils/TsNode/PrecompiledSourceMaps.js Index.js"]
