// A short end-to-end check of a deployed service: create, join, connect both,
// ready, start, relay a frame, end the run, and check both are back in the SAME
// lobby. Creates one room, so it is safe against production.
import WebSocket from "ws";

const base = process.env.FATE_BASE_URL;
if (!base) throw new Error("set FATE_BASE_URL");
const fate = "FL-SMKE-2222";
const post = async (path, body) => {
  const response = await fetch(base + path, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) });
  return { status: response.status, body: await response.json() };
};
const open = (code, token) =>
  new Promise((resolve, reject) => {
    const socket = new WebSocket(base.replace(/^http/, "ws") + `/v1/rooms/${code}/ws`, {
      headers: { Authorization: `Bearer ${token}`, "X-Fate-Protocol": "1" },
    });
    const client = { socket, messages: [], frames: [] };
    socket.on("message", (data, binary) => (binary ? client.frames.push(new Uint8Array(data)) : client.messages.push(JSON.parse(data.toString()))));
    socket.on("open", () => resolve(client));
    socket.on("error", reject);
    socket.on("unexpected-response", (_r, res) => reject(new Error("upgrade " + res.statusCode)));
  });
const until = async (check, label) => {
  for (let i = 0; i < 80; i++) {
    const value = check();
    if (value) return value;
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error("timed out: " + label);
};

const created = await post("/v1/rooms", { protocol: 1, name: "Smoke Host", fateId: fate, password: "smoke-test" });
if (created.status !== 201) throw new Error("create " + JSON.stringify(created));
const { code } = created.body;
const wrong = await post(`/v1/rooms/${code}/join`, { protocol: 1, name: "Nope", fateId: fate, password: "wrong" });
if (wrong.status !== 403) throw new Error("wrong password should be 403, got " + wrong.status);
const joined = await post(`/v1/rooms/${code}/join`, { protocol: 1, name: "Smoke Guest", fateId: fate, password: "smoke-test" });
if (joined.status !== 200) throw new Error("join " + JSON.stringify(joined));

const host = await open(code, created.body.token);
const guest = await open(code, joined.body.token);
guest.socket.send(JSON.stringify({ t: "ready", ready: true }));
await until(() => host.messages.find((m) => m.t === "room" && m.room.members.some((x) => x.ready)), "ready");
host.socket.send(JSON.stringify({ t: "start" }));
const start = await until(() => guest.messages.find((m) => m.t === "runStart"), "runStart");
guest.socket.send(Uint8Array.from([1, 9, 9]));
await until(() => host.frames.find((f) => f[0] === 1 && f[1] === 1), "relay");
host.socket.send(JSON.stringify({ t: "runEnd", runId: start.runId, outcome: "defeated", summary: { wave: 3 } }));
const lobby = await until(() => guest.messages.filter((m) => m.t === "room").reverse().find((m) => m.room.phase === "lobby" && m.room.lastRun), "lobby");
if (lobby.room.code !== code || lobby.room.members.length !== 2 || !lobby.room.hasPassword) throw new Error("not the same lobby");
host.socket.send(JSON.stringify({ t: "close" }));
await until(() => guest.messages.find((m) => m.t === "closed"), "closed");
console.log(`smoke ok against ${base}: room ${code} created, joined, played, returned to the same lobby, closed`);
process.exit(0);
