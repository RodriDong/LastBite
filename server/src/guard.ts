/**
 * Kiểm tra đăng nhập cho API: app gửi kèm Firebase ID token trong header
 * `Authorization: Bearer <token>`. Server xác thực bằng Admin SDK
 * (với Auth Emulator khi test local) rồi lấy uid + custom claims.
 */
import type { IncomingMessage } from "node:http";
import type { DecodedIdToken } from "firebase-admin/auth";
import { auth } from "./admin";
import { ApiError } from "./errors";

export interface AuthContext {
  uid: string;
  token: DecodedIdToken;
}

export async function requireAuth(req: IncomingMessage): Promise<AuthContext> {
  const header = req.headers.authorization ?? "";
  const match = /^Bearer (.+)$/.exec(
    Array.isArray(header) ? (header[0] ?? "") : header,
  );
  if (!match) {
    throw new ApiError("unauthenticated", "Bạn cần đăng nhập để thực hiện.");
  }
  try {
    const token = await auth().verifyIdToken(match[1]);
    return { uid: token.uid, token };
  } catch {
    throw new ApiError(
      "unauthenticated",
      "Phiên đăng nhập không hợp lệ hoặc đã hết hạn.",
    );
  }
}

/** Caller phải có custom claim `seller: true`. */
export async function requireSeller(
  req: IncomingMessage,
): Promise<AuthContext> {
  const ctx = await requireAuth(req);
  if (ctx.token.seller !== true) {
    throw new ApiError(
      "permission-denied",
      "Chỉ tài khoản seller mới thực hiện được.",
    );
  }
  return ctx;
}

/** Caller phải có custom claim `admin: true`. */
export async function requireAdmin(
  req: IncomingMessage,
): Promise<AuthContext> {
  const ctx = await requireAuth(req);
  if (ctx.token.admin !== true) {
    throw new ApiError(
      "permission-denied",
      "Chỉ admin mới thực hiện được thao tác này.",
    );
  }
  return ctx;
}
