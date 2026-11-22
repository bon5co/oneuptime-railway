// Sets OneUptime's GlobalConfig.disableSignup, the same switch the admin settings page flips, straight in PostgreSQL. The first-boot data
// migration seeds that column once from the DISABLE_SIGNUP environment variable, and with it on even the first account is refused, so it
// cannot be baked in: the owner has to exist before it is turned on. Exit 0 once the row reads true, 1 otherwise (the caller retries,
// because the GlobalConfig row is created by the app's own first-boot migration).
const { Client } = require("/usr/src/Common/node_modules/pg");

(async () => {
  const c = new Client({
    host: process.env.DATABASE_HOST,
    port: Number(process.env.DATABASE_PORT || 5432),
    user: process.env.DATABASE_USERNAME,
    password: process.env.DATABASE_PASSWORD,
    database: process.env.DATABASE_NAME,
  });
  await c.connect();
  const upd = await c.query('UPDATE "GlobalConfig" SET "disableSignup" = true');
  const back = await c.query('SELECT "disableSignup" FROM "GlobalConfig"');
  await c.end();
  if (upd.rowCount < 1 || back.rows.length < 1 || back.rows.some((r) => r.disableSignup !== true)) {
    console.error(`[railway-boot] GlobalConfig not closed yet: updated ${upd.rowCount} row(s)`);
    process.exit(1);
  }
  console.log("[railway-boot] sign-up is closed (GlobalConfig.disableSignup = true)");
})().catch((e) => {
  console.error(`[railway-boot] close-signup failed: ${e.message}`);
  process.exit(1);
});
