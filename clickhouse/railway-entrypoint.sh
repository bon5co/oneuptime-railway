#!/bin/sh
set -eu
rm -rf /var/lib/clickhouse/lost+found
exec /entrypoint.sh "$@"
