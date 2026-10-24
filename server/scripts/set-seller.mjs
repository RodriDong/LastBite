/**
 * Script chạy 1 lần ở máy dev: cấp custom claim `seller: true` cho 1 user
 * trên Firebase THẬT (cloud) + tạo stores/{uid} nếu chưa có.
 *
 * Vì sao cần: Firebase Console không có ô sửa custom claims.
 * Dùng Admin SDK với service-account key tải từ Console — key chỉ nằm
 * ở máy bạn, truyền qua biến môi trường, KHÔNG copy vào project.
 *
 * Cách chạy (PowerShell, trong thư mục server):
 *   $env:GOOGLE_APPLICATION_CREDENTIALS="C:\...\last-bite-xyz-firebase-adminsdk-....json"
 *   node scripts/set-seller.mjs <UID> [Tên cửa hàng]
 *
 * UID lấy ở Firebase Console -> Authentication -> cột UID của user.
 */
import { readFileSync } from "node:fs";
import { initializeApp, cert } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const [uid, storeNameArg] = process.argv.slice(2);
if (!uid) {
  console.error("Thiếu UID. Cách dùng: node scripts/set-seller.mjs <UID> [Tên cửa hàng]");
  process.exit(1);
}
const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!keyPath) {
  console.error("Chưa set biến môi trường GOOGLE_APPLICATION_CREDENTIALS (đường dẫn tới file khóa JSON).");
  process.exit(1);
}

const serviceAccount = JSON.parse(readFileSync(keyPath, "utf8"));
initializeApp({ credential: cert(serviceAccount) });

await getAuth().setCustomUserClaims(uid, { seller: true });
console.log(`✓ Đã cấp claim seller cho user ${uid}`);

const db = getFirestore();
const ref = db.doc(`stores/${uid}`);
const snap = await ref.get();
if (!snap.exists) {
  await ref.set({
    ownerUid: uid,
    name: storeNameArg ?? "Tiệm Lúa Mì",
    address: "",
    location: null,
    phone: null,
    rating: 0,
    ratingCount: 0,
    isApproved: true,
    openHours: null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  console.log(`✓ Đã tạo stores/${uid}`);
} else {
  console.log(`• stores/${uid} đã tồn tại, giữ nguyên.`);
}
console.log("Xong. Nhớ ĐĂNG XUẤT rồi ĐĂNG NHẬP LẠI trong app để nhận claim mới.");
process.exit(0);
