import type { IncomingMessage, ServerResponse } from "node:http";

/**
 * GET /api/health — kiểm tra server còn sống (không cần đăng nhập).
 * Viết độc lập, không import module nghiệp vụ: health phải trả lời được
 * ngay cả khi cấu hình Firebase Admin đang lỗi.
 */
export default function health(_req: IncomingMessage, res: ServerResponse) {
  res.writeHead(200, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
  });
  res.end(JSON.stringify({ ok: true, service: "lastbite-api" }));
}
