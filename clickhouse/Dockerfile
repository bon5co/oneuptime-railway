# ClickHouse for OneUptime on Railway. OneUptime's analytics schema is always sharded and replicated, so a single node has to be a "cluster
# of one" with the embedded Keeper; upstream mounts four XML drop-ins into the stock server image for that. Railway cannot mount files, so
# they are baked here, copied unmodified from OneUptime 17.1.0 (Clickhouse/config.d and Clickhouse/users.d).
# upstream: none ClickHouse base image, the OneUptime drop-ins are the content and are pinned to release 17.1.0
FROM clickhouse/clickhouse-server:26.7.38.18

COPY config.d/ /etc/clickhouse-server/config.d/
COPY users.d/ /etc/clickhouse-server/users.d/
# The volume arrives root-owned with a lost+found that ClickHouse would read as a database; the stock entrypoint then chowns and drops.
ENV CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1
COPY --chmod=0755 railway-entrypoint.sh /railway-entrypoint.sh
ENTRYPOINT ["/railway-entrypoint.sh"]
