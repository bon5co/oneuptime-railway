# oneuptime-railway

Wrapper images that let [OneUptime](https://github.com/OneUptime/oneuptime) (Apache-2.0) run as a Railway template.

- `ghcr.io/bon5co/oneuptime-railway` wraps `oneuptime/app` 17.1.0: starts the app on a private port, creates the owner account from
  `ADMIN_EMAIL` and `ADMIN_PASSWORD`, turns OneUptime's "disable sign up" setting on in the database, and only then opens the public port.
  A small proxy on the public port refuses nothing itself; it only reports the app's "sign up is turned off" answer as HTTP 403 instead of 400.
- `ghcr.io/bon5co/oneuptime-clickhouse-railway` wraps `clickhouse/clickhouse-server` with OneUptime's single-node cluster configuration baked in
  (copied unmodified from OneUptime 17.1.0) and clears the `lost+found` directory of a freshly mounted volume.

The Railway template that uses both is published from the `bon5co` workspace; this repository holds only the images.
