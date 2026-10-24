/**
 * Script chạy 1 lần ở máy dev: cấp custom claim `admin: true` cho 1 user
 * trên Firebase THẬT (cloud) — để tài khoản đó duyệt chứng nhận ATTP
 * ngay trong app (endpoint reviewCertificate, mode "admin").
 *
 * Cách chạy (PowerShell, trong thư mục server):
 *   $env:GOOGLE_APPLICATION_CREDENTIALS="C:\...\last-bite-xyz-firebase-adminsdk-....json"
 *   node scripts/set-admin.mjs <UID>
 *
 * UID lấy ở Firebase Console -> Authentication -> cột UID của user.
 * Sau khi chạy, user phải ĐĂNG XUẤT rồi đăng nhập lại để nhận claim mới.
 */
import { readFileSync } from "node:fs";
import { initializeApp, cert } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

const [uid] = process.argv.slice(2);
if (!uid) {
  console.error("Thiếu UID. Cách dùng: node scripts/set-admin.mjs <UID>");
  process.exit(1);
}
const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!keyPath) {
  console.error("Chưa set biến môi trường GOOGLE_APPLICATION_CREDENTIALS (đường dẫn tới file khóa JSON).");
  process.exit(1);
}

const serviceAccount = JSON.parse(readFileSync(keyPath, "utf8"));
initializeApp({ credential: cert(serviceAccount) });

const user = await getAuth().getUser(uid);
const claims = { ...(user.customClaims ?? {}), admin: true };
await getAuth().setCustomUserClaims(uid, claims);
console.log(`✓ Đã cấp claim admin cho user ${uid} (giữ nguyên các claim cũ: ${JSON.stringify(user.customClaims ?? {})})`);
console.log("→ User cần đăng xuất rồi đăng nhập lại để nhận quyền mới.");
