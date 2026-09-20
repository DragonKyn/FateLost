/**
 * Randomness and hashing, all through the Web Crypto API the Workers runtime
 * provides. Nothing here logs or returns a secret.
 */
import { ROOM_CODE_ALPHABET, ROOM_CODE_LENGTH } from "./protocol";

const encoder = new TextEncoder();

export function randomBytes(length: number): Uint8Array {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return bytes;
}

export function toBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function fromBase64Url(text: string): Uint8Array {
  const padded = text.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (text.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

export function toHex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

/**
 * A uniformly random integer below `limit`. Rejection sampling, so the room
 * alphabet is not skewed by a modulo.
 */
export function randomBelow(limit: number): number {
  const range = 0x1_0000_0000;
  const ceiling = range - (range % limit);
  const buffer = new Uint32Array(1);
  for (;;) {
    crypto.getRandomValues(buffer);
    const value = buffer[0] ?? 0;
    if (value < ceiling) return value % limit;
  }
}

/** A room code like F7K2Q9. */
export function generateRoomCode(): string {
  let code = "";
  for (let index = 0; index < ROOM_CODE_LENGTH; index++) {
    code += ROOM_CODE_ALPHABET[randomBelow(ROOM_CODE_ALPHABET.length)];
  }
  return code;
}

/** The room-scoped credential handed to one member. 256 bits. */
export function generateToken(): string {
  return toBase64Url(randomBytes(32));
}

/** A member id: public inside the room, meaningless outside it. */
export function generateMemberId(): string {
  return toHex(randomBytes(8));
}

/** A run seed as a decimal string, so no JSON number loses precision. */
export function generateSeed(): string {
  const bytes = randomBytes(8);
  let value = 0n;
  for (const byte of bytes) value = (value << 8n) | BigInt(byte);
  return value.toString();
}

export function generateRunId(): string {
  return toHex(randomBytes(6));
}

export async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(text));
  return toHex(new Uint8Array(digest));
}

/** Compares in time that does not depend on where the strings differ. */
export function constantTimeEqual(a: string, b: string): boolean {
  const left = encoder.encode(a);
  const right = encoder.encode(b);
  let difference = left.length ^ right.length;
  const length = Math.max(left.length, right.length);
  for (let index = 0; index < length; index++) {
    difference |= (left[index] ?? 0) ^ (right[index] ?? 0);
  }
  return difference === 0;
}

export interface PasswordRecord {
  salt: string;
  hash: string;
  iterations: number;
}

async function derive(password: string, salt: Uint8Array, iterations: number): Promise<string> {
  const key = await crypto.subtle.importKey("raw", encoder.encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", hash: "SHA-256", salt: salt as BufferSource, iterations },
    key,
    256,
  );
  return toBase64Url(new Uint8Array(bits));
}

/** A salted verifier. The password itself is never stored. */
export async function hashPassword(password: string, iterations: number): Promise<PasswordRecord> {
  const salt = randomBytes(16);
  return { salt: toBase64Url(salt), hash: await derive(password, salt, iterations), iterations };
}

export async function verifyPassword(password: string, record: PasswordRecord): Promise<boolean> {
  const candidate = await derive(password, fromBase64Url(record.salt), record.iterations);
  return constantTimeEqual(candidate, record.hash);
}
