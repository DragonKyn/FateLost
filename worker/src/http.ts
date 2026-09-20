import { ApiError } from "./protocol";

export function json(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store", ...headers },
  });
}

export function errorResponse(error: unknown): Response {
  if (error instanceof ApiError) {
    const headers: Record<string, string> = {};
    const retryAfter = error.extra.retryAfter;
    if (typeof retryAfter === "number") headers["retry-after"] = String(Math.ceil(retryAfter));
    return json({ error: { code: error.code, message: error.message, ...error.extra } }, error.status, headers);
  }
  // Never echo an unexpected error: it could carry something it should not.
  console.error("unexpected error", error instanceof Error ? error.name : "unknown");
  return json({ error: { code: "internal", message: "Something went wrong." } }, 500);
}

/** Reads a small JSON body, refusing anything large before parsing it. */
export async function readJson(request: Request, maxBytes: number): Promise<unknown> {
  const declared = Number(request.headers.get("content-length") ?? "0");
  if (declared > maxBytes) throw new ApiError("too_large", "Request is too large.", 413);
  const text = await request.text();
  if (text.length > maxBytes) throw new ApiError("too_large", "Request is too large.", 413);
  try {
    return JSON.parse(text);
  } catch {
    throw new ApiError("bad_request", "Body is not valid JSON.", 400);
  }
}
