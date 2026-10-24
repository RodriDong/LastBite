/**
 * Lỗi nghiệp vụ của API server — thay cho HttpsError của Cloud Functions
 * (giữ nguyên bộ mã lỗi để app xử lý giống hệt trước đây).
 * Xem docs/backend-contract.md.
 */
export class ApiError extends Error {
  constructor(
    public code: string,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

/** Ánh xạ mã lỗi -> HTTP status khi trả về cho app. */
export function httpStatusFor(code: string): number {
  switch (code) {
    case "invalid-argument":
      return 400;
    case "unauthenticated":
      return 401;
    case "permission-denied":
      return 403;
    case "not-found":
      return 404;
    case "failed-precondition":
    case "already-exists":
      return 409;
    case "resource-exhausted":
      return 429;
    case "unavailable":
      return 503;
    case "unimplemented":
      return 501;
    default:
      return 500; // internal và các mã lạ
  }
}
