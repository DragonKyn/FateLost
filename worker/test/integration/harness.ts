import WebSocket from "ws";

export const BASE_URL = process.env.FATE_BASE_URL ?? "http://127.0.0.1:8811";
/** Timing tests need the short-lifetime `test` environment. */
export const TIMING_TESTS = process.env.TIMING_TESTS === "1";
export const PROTOCOL = 1;

let counter = 0;

/** A name that makes each test's requests count against their own throttle. */
export function testClientId(): string {
  counter += 1;
  return `t${Date.now().toString(36)}${counter}${Math.random().toString(36).slice(2, 6)}`;
}

let fateCounter = 0;
export function fateId(): string {
  fateCounter += 1;
  const alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
  const pick = (index: number) => alphabet[(index * 7 + fateCounter * 3) % alphabet.length];
  return `FL-${pick(1)}${pick(2)}${pick(3)}${pick(4)}-${pick(5)}${pick(6)}${pick(7)}${pick(fateCounter)}`;
}

export interface ApiResult<T = any> {
  status: number;
  body: T;
}

export async function post(path: string, body: unknown, clientId: string): Promise<ApiResult> {
  const response = await fetch(`${BASE_URL}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json", "X-Test-Client-Id": clientId },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
  const text = await response.text();
  let parsed: any = text;
  try {
    parsed = JSON.parse(text);
  } catch {
    // Leave the text as it is.
  }
  return { status: response.status, body: parsed };
}

export interface Session {
  code: string;
  playerId: string;
  token: string;
  name: string;
  clientId: string;
}

export async function createRoom(name = "Host", password?: string, clientId = testClientId()): Promise<Session> {
  const result = await post("/v1/rooms", { protocol: PROTOCOL, name, fateId: fateId(), password }, clientId);
  if (result.status !== 201) throw new Error(`create failed: ${result.status} ${JSON.stringify(result.body)}`);
  return { code: result.body.code, playerId: result.body.playerId, token: result.body.token, name, clientId };
}

export async function joinRoom(code: string, name: string, password?: string, clientId = testClientId()) {
  return post(`/v1/rooms/${code}/join`, { protocol: PROTOCOL, name, fateId: fateId(), password }, clientId);
}

export async function joined(code: string, name: string, password?: string): Promise<Session> {
  const clientId = testClientId();
  const result = await joinRoom(code, name, password, clientId);
  if (result.status !== 200) throw new Error(`join failed: ${result.status} ${JSON.stringify(result.body)}`);
  return { code, playerId: result.body.playerId, token: result.body.token, name, clientId };
}

/** A connected member, recording everything it receives. */
export class Client {
  readonly messages: any[] = [];
  readonly frames: Uint8Array[] = [];
  closeCode: number | null = null;
  private waiters: Array<() => void> = [];

  private constructor(
    readonly session: Session,
    readonly socket: WebSocket,
  ) {
    socket.on("message", (data: Buffer, isBinary: boolean) => {
      if (isBinary) this.frames.push(new Uint8Array(data));
      else this.messages.push(JSON.parse(data.toString()));
      this.wake();
    });
    socket.on("close", (code: number) => {
      this.closeCode = code;
      this.wake();
    });
  }

  static async connect(session: Session, headers: Record<string, string> = {}): Promise<Client> {
    const url = `${BASE_URL.replace(/^http/, "ws")}/v1/rooms/${session.code}/ws`;
    const socket = new WebSocket(url, {
      headers: {
        Authorization: `Bearer ${session.token}`,
        "X-Fate-Protocol": String(PROTOCOL),
        "X-Test-Client-Id": session.clientId,
        ...headers,
      },
    });
    const client = new Client(session, socket);
    await new Promise<void>((resolve, reject) => {
      socket.once("open", () => resolve());
      socket.once("unexpected-response", (_request, response) => {
        reject(new Error(`upgrade refused: ${response.statusCode}`));
      });
      socket.once("error", reject);
    });
    return client;
  }

  private wake(): void {
    const waiting = this.waiters;
    this.waiters = [];
    for (const wake of waiting) wake();
  }

  private async pause(timeoutMs: number): Promise<void> {
    await new Promise<void>((resolve) => {
      const timer = setTimeout(resolve, timeoutMs);
      this.waiters.push(() => {
        clearTimeout(timer);
        resolve();
      });
    });
  }

  send(message: unknown): void {
    this.socket.send(JSON.stringify(message));
  }

  sendBinary(bytes: number[]): void {
    this.socket.send(Uint8Array.from(bytes));
  }

  /** Waits until a received message satisfies the predicate. */
  async waitFor<T = any>(predicate: (message: any) => boolean, timeoutMs = 4000, from = 0): Promise<T> {
    const deadline = Date.now() + timeoutMs;
    for (;;) {
      const found = this.messages.slice(from).find(predicate);
      if (found) return found as T;
      const remaining = deadline - Date.now();
      if (remaining <= 0) {
        throw new Error(`timed out waiting; saw ${JSON.stringify(this.messages.slice(-6).map((m) => m.t ?? m))}`);
      }
      await this.pause(remaining);
    }
  }

  /** Resolves with the first `room` message (from index `from` on) that matches. */
  async room(predicate: (room: any) => boolean = () => true, timeoutMs = 4000, from = 0): Promise<any> {
    const message = await this.waitFor((m) => m.t === "room" && predicate(m.room), timeoutMs, from);
    return message.room;
  }

  async waitForFrame(predicate: (frame: Uint8Array) => boolean, timeoutMs = 4000): Promise<Uint8Array> {
    const deadline = Date.now() + timeoutMs;
    for (;;) {
      const found = this.frames.find(predicate);
      if (found) return found;
      const remaining = deadline - Date.now();
      if (remaining <= 0) throw new Error("timed out waiting for a binary frame");
      await this.pause(remaining);
    }
  }

  /**
   * Resolves with the close code once the server has closed the connection.
   * The `ws` client only reports a close after the TCP connection ends, which
   * the local dev runtime is slow to do, so the code from the close frame
   * (available as soon as the socket is closing) is what is used.
   */
  async waitForClose(timeoutMs = 4000): Promise<number> {
    const deadline = Date.now() + timeoutMs;
    for (;;) {
      if (this.closeCode !== null) return this.closeCode;
      const frameCode = (this.socket as unknown as { _closeCode?: number })._closeCode;
      if (this.socket.readyState >= WebSocket.CLOSING && typeof frameCode === "number" && frameCode !== 1005) {
        return frameCode;
      }
      const remaining = deadline - Date.now();
      if (remaining <= 0) throw new Error("timed out waiting for close");
      await this.pause(Math.min(remaining, 50));
    }
  }

  close(): void {
    this.socket.close(1000);
  }
}

export const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
