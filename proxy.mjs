// Public front door on the injected PORT. Everything goes to the app on loopback, websockets included. One response is rewritten: with
// sign-up turned off OneUptime answers the sign-up call with HTTP 400 and a "Sign up is turned off" message, which reads like a malformed
// request to a client. Only that exact refusal on that exact route becomes 403, so every other 400 keeps its status.
import http from "node:http";

const port = Number(process.env.PUBLIC_PORT);
const appPort = Number(process.env.APP_PORT || 3002);
const isSignup = (req) => req.method === "POST" && req.url.split("?")[0].replace(/\/+$/, "") === "/api/identity/signup";

const server = http.createServer((req, res) => {
  const up = http.request({ host: "127.0.0.1", port: appPort, method: req.method, path: req.url, headers: req.headers }, (r) => {
    if (isSignup(req) && r.statusCode === 400) {
      const chunks = [];
      r.on("data", (c) => chunks.push(c));
      r.on("end", () => {
        const body = Buffer.concat(chunks);
        const refused = body.toString("utf8").includes("Sign up is turned off");
        const headers = { ...r.headers, "content-length": body.length };
        res.writeHead(refused ? 403 : 400, headers);
        res.end(body);
      });
      return;
    }
    res.writeHead(r.statusCode, r.headers);
    r.pipe(res);
  });
  up.on("error", () => {
    if (!res.headersSent) res.writeHead(502, { "content-type": "text/plain" });
    res.end("upstream unavailable");
  });
  req.pipe(up);
});

server.on("upgrade", (req, socket, head) => {
  const up = http.request({ host: "127.0.0.1", port: appPort, method: req.method, path: req.url, headers: req.headers });
  up.on("upgrade", (r, s, h) => {
    socket.write(`HTTP/1.1 101 Switching Protocols\r\n${Object.entries(r.headers).map(([k, v]) => `${k}: ${v}`).join("\r\n")}\r\n\r\n`);
    if (h.length) socket.write(h);
    s.pipe(socket).pipe(s);
  });
  up.on("error", () => socket.destroy());
  socket.on("error", () => up.destroy());
  up.end(head);
});

server.listen(port, "::", () => console.log(`[railway-boot] public port ${port} open`));
