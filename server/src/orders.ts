/**
 * Phase 4 — Orders: validation thuần + tiện ích (không phụ thuộc Admin SDK)
 * cho createOrder / cancelOrder / confirmPickup. Dùng chung bởi index.ts
 * và unit test.
 *
 * Xem docs/backend-contract.md §2.1–2.3 và docs/firestore-schema.md §4.
 */

import { ApiError } from "./errors";

function invalid(msg: string): ApiError {
  return new ApiError("invalid-argument", msg);
}

function asString(v: unknown): string | null {
  return typeof v === "string" ? v : null;
}

// ---------------------------------------------------------------------------
// createOrder
// ---------------------------------------------------------------------------

export interface CreateOrderInput {
  dealId: string;
  quantity: number; // int, 1..99
  pickupSlot: string;
  paymentMethod: string; // momo | vnpay | zalopay | payos | vietqr
}

export function validateCreateOrderInput(data: unknown): CreateOrderInput {
  if (typeof data !== "object" || data === null) {
    throw invalid("Dữ liệu đơn hàng không hợp lệ.");
  }
  const d = data as Record<string, unknown>;

  const dealId = asString(d.dealId)?.trim();
  if (!dealId) throw invalid("Thiếu dealId.");

  const quantity = d.quantity;
  if (
    typeof quantity !== "number" ||
    !Number.isInteger(quantity) ||
    quantity < 1 ||
    quantity > 99
  ) {
    throw invalid("Số lượng phải là số nguyên từ 1 đến 99.");
  }

  const pickupSlot = asString(d.pickupSlot)?.trim();
  if (!pickupSlot) throw invalid("Thiếu khung giờ nhận (pickupSlot).");

  const rawMethod = asString(d.paymentMethod)?.trim().toLowerCase() ?? "";
  const paymentMethod = rawMethod === "" ? "vietqr" : rawMethod;
  if (
    !["momo", "vnpay", "zalopay", "payos", "vietqr"].includes(paymentMethod)
  ) {
    throw invalid("Phương thức thanh toán không hợp lệ.");
  }

  return { dealId, quantity, pickupSlot, paymentMethod };
}

// ---------------------------------------------------------------------------
// cancelOrder
// ---------------------------------------------------------------------------

export interface CancelOrderInput {
  orderId: string;
}

export function validateCancelOrderInput(data: unknown): CancelOrderInput {
  if (typeof data !== "object" || data === null) {
    throw invalid("Dữ liệu không hợp lệ.");
  }
  const d = data as Record<string, unknown>;
  const orderId = asString(d.orderId)?.trim();
  if (!orderId) throw invalid("Thiếu orderId.");
  return { orderId };
}

// ---------------------------------------------------------------------------
// confirmPickup
// ---------------------------------------------------------------------------

export interface ConfirmPickupInput {
  pickupCode: string; // đã chuẩn hóa: trim + uppercase + bỏ '#'
}

export function validateConfirmPickupInput(
  data: unknown,
): ConfirmPickupInput {
  if (typeof data !== "object" || data === null) {
    throw invalid("Dữ liệu không hợp lệ.");
  }
  const d = data as Record<string, unknown>;
  const raw = asString(d.pickupCode);
  const pickupCode = raw?.trim().toUpperCase().replace(/#/g, "") ?? "";
  if (!pickupCode) throw invalid("Thiếu mã nhận hàng (pickupCode).");
  return { pickupCode };
}

// ---------------------------------------------------------------------------
// Tiện ích
// ---------------------------------------------------------------------------

/**
 * Mã nhận hàng dạng "AXXXX" (X: chữ số), giữ format như UI mock hiện tại.
 * Việc đảm bảo unique (trong các đơn PENDING) do handler kiểm tra lại.
 */
export function generatePickupCodeCandidate(): string {
  return `A${1000 + Math.floor(Math.random() * 9000)}`;
}

/**
 * Khóa ngày cho stores/{storeId}/dailyStats/{yyyyMMdd} theo múi giờ
 * Asia/Ho_Chi_Minh (báo cáo doanh thu theo giờ VN, không theo UTC).
 */
export function dailyStatsKey(date: Date = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
  return `${get("year")}${get("month")}${get("day")}`;
}
