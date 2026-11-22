#!/bin/sh
# OneUptime app on Railway. Order matters: start the app on its own private port, wait until it can take the first account, create the owner,
# close sign-up in the database, and only then open the public port. A green healthcheck therefore means a deploy that is already signed up
# for and already closed to strangers. A redeploy finds the owner in place, skips the sign-up, and re-asserts the closed state.
set -eu

need() { eval "v=\${$1:-}"; [ -n "$v" ] || { echo "[railway-boot] $1 is required" >&2; exit 1; }; }
for n in HOST ONEUPTIME_SECRET ENCRYPTION_SECRET REGISTER_PROBE_KEY DATABASE_HOST DATABASE_USERNAME DATABASE_PASSWORD DATABASE_NAME \
         VALKEY_HOST VALKEY_PASSWORD CLICKHOUSE_HOST CLICKHOUSE_USER CLICKHOUSE_PASSWORD CLICKHOUSE_DATABASE ADMIN_EMAIL ADMIN_PASSWORD; do need "$n"; done
[ "${#ADMIN_PASSWORD}" -ge 12 ] || { echo "[railway-boot] ADMIN_PASSWORD must be at least 12 characters" >&2; exit 1; }
case "$ADMIN_EMAIL" in *[!A-Za-z0-9@._+-]*) echo "[railway-boot] ADMIN_EMAIL has characters outside A-Za-z0-9@._+-" >&2; exit 1;; esac
case "$ADMIN_PASSWORD" in *[!A-Za-z0-9._+-]*) echo "[railway-boot] ADMIN_PASSWORD has characters outside A-Za-z0-9._+-" >&2; exit 1;; esac

# Railway injects PORT (8080) into every service and the healthcheck dials it, so PORT is the public front door's alone. The app keeps 3002.
export PUBLIC_PORT="${PORT:-8080}"
export PORT=3002 APP_PORT=3002
APP_URL="http://127.0.0.1:$APP_PORT"

trap 'kill -TERM "${APP:-}" "${PROXY:-}" 2>/dev/null' TERM INT
docker-entrypoint.sh "$@" &
APP=$!

alive() { kill -0 "$APP" 2>/dev/null || { wait "$APP"; exit $?; }; }

# POST /api/identity/first-account answers {"isAwaitingFirstAccount":true} while no account exists and false afterwards. It reads the database,
# so it is the readiness test for the sign-up and not just for the HTTP listener.
n=0
while :; do
  alive
  CODE=$(curl -s -o /tmp/first.out -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{}' "$APP_URL/api/identity/first-account" || true)
  if [ "$CODE" = 200 ]; then
    if grep -q '"isAwaitingFirstAccount":true' /tmp/first.out; then STATE=empty; break; fi
    if grep -q '"isAwaitingFirstAccount":false' /tmp/first.out; then STATE=exists; break; fi
  fi
  n=$((n+1)); [ "$n" -le 600 ] || { echo "[railway-boot] app did not become ready within 600s (last HTTP $CODE)" >&2; kill "$APP"; exit 1; }
  sleep 1
done

if [ "$STATE" = empty ]; then
  BODY=$(printf '{"data":{"email":{"_type":"Email","value":"%s"},"name":{"_type":"Name","value":"Admin"},"password":"%s"}}' "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
  CODE=$(curl -s -o /tmp/signup.out -w '%{http_code}' -H 'content-type: application/json' -d "$BODY" "$APP_URL/api/identity/signup" || true)
  [ "$CODE" = 200 ] || { echo "[railway-boot] owner bootstrap failed: HTTP $CODE $(head -c 300 /tmp/signup.out)" >&2; kill "$APP"; exit 1; }
  echo "[railway-boot] owner account created for $ADMIN_EMAIL"
else
  echo "[railway-boot] owner bootstrap skipped: an account already exists"
fi
rm -f /tmp/first.out /tmp/signup.out

# The GlobalConfig row is written by the app's first-boot migration, which can still be running when the sign-up above succeeds.
n=0
until node /usr/src/app/railway-close-signup.cjs; do
  alive
  n=$((n+1)); [ "$n" -le 120 ] || { echo "[railway-boot] could not close sign-up after 120 attempts" >&2; kill "$APP"; exit 1; }
  sleep 2
done

node /railway-proxy.mjs &
PROXY=$!
wait "$APP"
