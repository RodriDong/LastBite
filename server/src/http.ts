/**
 * Adapter HTTP dùng chung cho cả Vercel (serverless functions nhận
 * req/res kiểu Node) và server local (src/local.ts).
 *
 * Giao thức (giữ tương thích cách app xử lý lỗi từ thời Cloud Functions):
 *  - Request: POST, body JSON, header Authorization: Bearer <ID token>.
 *  - Thành công: HTTP 200, body JSON là kết quả handler trả về.
 *  - Lỗi nghiệp vụ: HTTP theo httpStatusFor(code), body
 *    { "error": "<message tiếng Việt>", "code": "<mã lỗi>" }.
 *
 * CORS: app web (Flutter Web trên Chrome khi dev) gọi API khác origin nên
 * trình duyệt gửi preflight OPTIONS — server PHẢI trả lời kèm header
 * Access-Control-* thì trình duyệt mới cho request thật đi tiếp. App
 * native (Android/iOS) không cần CORS nhưng có header cũng vô hại.
 */
import type { IncomingMessage, ServerResponse } from "node:http";
import type { AuthContext } from "./guard";
import { requireAuth, requireSeller, requireAdmin } from "./guard";
import { ApiError, httpStatusFor } from "./errors";

export const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
  "Access-Control-Max-Age": "86400",
};

/** Trả lời preflight của trình duyệt. */
export function handlePreflight(res: ServerResponse): void {
  res.writeHead(204, CORS_HEADERS);
  res.end();
}

export type AuthMode = "auth" | "seller" | "admin";
export type HandlerFn = (
  ctx: AuthContext,
  data: Record<string, unknown>,
) => Promise<unknown>;

async function readBody(req: IncomingMessage): Promise<Record<string, unknown>> {
  // Vercel có thể đã parse sẵn body.
  const anyReq = req as IncomingMessage & { body?: unknown };
  if (anyReq.body && typeof anyReq.body === "object") {
    return anyReq.body as Record<string, unknown>;
  }
  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    chunks.push(chunk as Buffer);
  }
  const text = Buffer.concat(chunks).toString("utf8").trim();
  if (!text) return {};
  try {
    const parsed = JSON.parse(text) as unknown;
    if (typeof parsed !== "object" || parsed === null) return {};
    return parsed as Record<string, unknown>;
  } catch {
    throw new ApiError("invalid-argument", "Body phải là JSON hợp lệ.");
  }
}

function sendJson(res: ServerResponse, status: number, payload: unknown) {
  const body = JSON.stringify(payload ?? {});
  res.writeHead(status, {
    "Content-Type": "application/json",
    ...CORS_HEADERS,
  });
  res.end(body);
}

/** Tạo một endpoint POST có kiểm tra đăng nhập theo [mode]. */
export function createEndpoint(mode: AuthMode, run: HandlerFn) {
  return async (req: IncomingMessage, res: ServerResponse) => {
    try {
      if (req.method === "OPTIONS") {
        handlePreflight(res);
        return;
      }
      if (req.method !== "POST") {
        throw new ApiError("invalid-argument", "Chỉ hỗ trợ POST.");
      }
      const ctx =
        mode === "seller"
          ? await requireSeller(req)
          : mode === "admin"
            ? await requireAdmin(req)
            : await requireAuth(req);
      const data = await readBody(req);
      const result = await run(ctx, data);
      sendJson(res, 200, result);
    } catch (e) {
      if (e instanceof ApiError) {
        sendJson(res, httpStatusFor(e.code), {
          error: e.message,
          code: e.code,
        });
      } else {
        console.error("Unhandled API error:", e);
        sendJson(res, 500, {
          error: "Lỗi hệ thống. Thử lại sau.",
          code: "internal",
        });
      }
    }
  };
}
