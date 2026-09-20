// Starts `wrangler dev` (the local, short-lifetime `test` environment), waits
// for it to answer, runs the given command against it and then stops it.
import { spawn, spawnSync } from "node:child_process";

const port = process.env.DEV_PORT ?? "8811";
const base = `http://127.0.0.1:${port}`;
const [command, ...args] = process.argv.slice(2);
if (!command) {
  console.error("usage: with-dev-server.mjs <command> [args...]");
  process.exit(2);
}

const server = spawn("npx", ["wrangler", "dev", "--local", "--env", "test", "--port", port], {
  stdio: ["ignore", "pipe", "pipe"],
  shell: true,
});
let log = "";
server.stdout.on("data", (chunk) => (log += chunk));
server.stderr.on("data", (chunk) => (log += chunk));

function stop() {
  if (process.platform === "win32") {
    spawnSync("taskkill", ["/F", "/T", "/PID", String(server.pid)], { stdio: "ignore" });
  } else {
    server.kill("SIGTERM");
  }
}

let ready = false;
for (let attempt = 0; attempt < 90 && !ready; attempt++) {
  try {
    const response = await fetch(`${base}/health`);
    ready = response.ok;
  } catch {
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
}
if (!ready) {
  console.error("dev server did not start:\n" + log.slice(-2000));
  stop();
  process.exit(1);
}

const child = spawn(command, args, {
  stdio: "inherit",
  shell: true,
  env: { ...process.env, FATE_BASE_URL: base, TIMING_TESTS: "1" },
});
child.on("exit", (code) => {
  stop();
  process.exit(code ?? 1);
});
