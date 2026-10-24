import type { IncomingMessage, ServerResponse } from "node:http";
import { ROUTES } from "../src/routes";
import { CORS_HEADERS } from "../src/http";
import health from "./health";

/**
 * Router duy nhất cho Vercel (gói Hobby giới hạn 12 function/deployment).
 * Vercel map file `api/[endpoint].ts` -> /api/:endpoint, nên mọi endpoint
 * POST đều chạy qua 1 function này; URL phía app giữ nguyên, không đổi gì.
 * Endpoint mới chỉ cần thêm vào src/routes.ts (local.ts dùng chung bảng đó).
 */
export default async function router(req: IncomingMessage, res: ServerResponse) {
  const path = (req.url ?? "").split("?")[0];
  const name = path.replace(/^\/api\//, "");
  if (name === "health" || name === "") {
    return health(req, res);
  }
  const route = ROUTES[`/api/${name}`];
  if (!route) {
    res.writeHead(404, {
      "Content-Type": "application/json",
      ...CORS_HEADERS,
    });
    res.end(
      JSON.stringify({ error: "Không tìm thấy endpoint.", code: "not-found" }),
    );
    return;
  }
  return route(req, res);
}
