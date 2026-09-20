import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const root = join(__dirname, "..", "..");

function sourceFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    return statSync(path).isDirectory() ? sourceFiles(path) : path.endsWith(".ts") ? [path] : [];
  });
}

describe("logging volume", () => {
  const config = readFileSync(join(root, "wrangler.toml"), "utf8");

  it("switches invocation logs off in production and staging", () => {
    // Every request and every WebSocket message would otherwise be an event.
    expect(config).toMatch(/\[observability\.logs\][^\[]*invocation_logs\s*=\s*false/);
    expect(config).toMatch(/\[env\.staging\.observability\.logs\][^\[]*invocation_logs\s*=\s*false/);
    expect(config).not.toMatch(/invocation_logs\s*=\s*true/);
  });

  it("writes only rare error lines from the code", () => {
    const calls: string[] = [];
    for (const file of sourceFiles(join(root, "src"))) {
      for (const line of readFileSync(file, "utf8").split("\n")) {
        if (/console\.\w+\(/.test(line)) calls.push(line.trim());
      }
    }
    // Only console.error, and only in the two places that guard against a bug.
    expect(calls.length).toBeLessThanOrEqual(2);
    expect(calls.every((line) => line.startsWith("console.error("))).toBe(true);
  });

  it("never logs from the per-message or per-tick paths", () => {
    const room = readFileSync(join(root, "src", "partyRoom.ts"), "utf8");
    const relay = room.slice(room.indexOf("private relay("), room.indexOf("// MARK: - Alarm"));
    expect(relay).not.toMatch(/console\./);
    const handler = room.slice(room.indexOf("override async webSocketMessage"), room.indexOf("private relay("));
    // The one error line in the handler is inside the catch for an unexpected failure.
    const lines = handler.split("\n").filter((line) => /console\./.test(line));
    expect(lines).toHaveLength(1);
    expect(handler.indexOf("console.")).toBeGreaterThan(handler.indexOf("catch (error)"));
  });
});
