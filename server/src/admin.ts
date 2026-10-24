/**
 * Khởi tạo Firebase Admin SDK cho API server (chạy trên Vercel hoặc local).
 *
 * Thứ tự ưu tiên cấu hình:
 * 1. Env `FIREBASE_SERVICE_ACCOUNT` = JSON service account (trên Vercel —
 *    đặt ở Environment Variables, TUYỆT ĐỐI không commit vào repo).
 * 2. Chế độ Emulator khi test local: env `FIRESTORE_EMULATOR_HOST` /
 *    `FIREBASE_AUTH_EMULATOR_HOST` + `FIREBASE_PROJECT_ID` — không cần key.
 */
import { getApps, initializeApp, cert } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

let initialized = false;

export function ensureAdmin(): void {
  if (initialized || getApps().length > 0) {
    initialized = true;
    return;
  }
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (raw) {
    initializeApp({ credential: cert(JSON.parse(raw)) });
  } else if (process.env.FIRESTORE_EMULATOR_HOST) {
    // Test local với Emulator Suite — Admin SDK tự trỏ vào emulator
    // khi thấy các env *_EMULATOR_HOST.
    initializeApp({
      projectId: process.env.FIREBASE_PROJECT_ID ?? "last-bite-xyz",
    });
  } else {
    throw new Error(
      "Thiếu cấu hình Firebase Admin: cần env FIREBASE_SERVICE_ACCOUNT " +
        "(trên Vercel) hoặc FIRESTORE_EMULATOR_HOST (test local).",
    );
  }
  initialized = true;
}

export function db() {
  ensureAdmin();
  return getFirestore();
}

export function auth() {
  ensureAdmin();
  return getAuth();
}
