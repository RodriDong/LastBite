/**
 * Server chạy local để test cùng Firebase Emulator Suite — ánh xạ cùng
 * các route như trên Vercel (/api/<tên>).
 *
 * Chạy: npm run build && npm start
 * Env cần khi test local:
 *   FIRESTORE_EMULATOR_HOST=localhost:8080
 *   FIREBASE_AUTH_EMULATOR_HOST=localhost:9099
 *   FIREBASE_PROJECT_ID=last-bite-xyz
 *   PORT=3000 (mặc định)
 */
import { createServer } from "node:http";
import { CORS_HEADERS, handlePreflight } from "./http";
import { ROUTES as routes } from "./routes";

const port = Number(process.env.PORT ?? 3000);

createServer((req, res) => {
  const path = (req.url ?? "").split("?")[0];
  if (req.method === "OPTIONS") {
    handlePreflight(res);
    return;
  }
  if (path === "/api/health") {
    res.writeHead(200, { "Content-Type": "application/json", ...CORS_HEADERS });
    res.end(JSON.stringify({ ok: true }));
    return;
  }
  const route = routes[path];
  if (!route) {
    res.writeHead(404, { "Content-Type": "application/json", ...CORS_HEADERS });
    res.end(JSON.stringify({ error: "Không tìm thấy endpoint.", code: "not-found" }));
    return;
  }
  void route(req, res);
}).listen(port, () => {
  console.log(`LastBite API (local) đang chạy ở http://localhost:${port}`);
});
