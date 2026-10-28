/**
 * Nguồn chân lý DUY NHẤT cho logic giảm giá theo giờ.
 * Xem docs/backend-contract.md §1 và docs/firestore-schema.md §3.
 *
 * Quy tắc demo:
 *  - remaining > 180 phút            → giảm 20%
 *  - 60 phút <= remaining <= 180 phút → giảm 40%
 *  - 0 < remaining < 60 phút          → giảm maxDiscountPercent (mặc định 60%)
 *  - remaining <= 0                   → hết giờ, không cho đặt
 *
 * Tiền là số nguyên VNĐ, làm tròn đến nghìn đồng, không thấp hơn minPrice.
 * Client (Dart) chỉ dùng công thức tương đương để PREVIEW; createOrder
 * luôn tính lại ở server.
 */

export interface DealPricingInput {
  originalPrice: number; // int, VNĐ
  minPrice: number; // int, VNĐ — giá sàn
  maxDiscountPercent?: number; // mặc định 60
}

export const DEFAULT_MAX_DISCOUNT = 60;
export const MS_PER_MINUTE = 60_000;

/**
 * Trả về % giảm giá, hoặc null nếu đã hết giờ.
 * @param remainingMs saleEndAt - now (millisecond)
 */
export function discountPercentFor(
  remainingMs: number,
  maxDiscountPercent: number = DEFAULT_MAX_DISCOUNT,
): number | null {
  if (remainingMs <= 0) return null;
  if (remainingMs > 180 * MS_PER_MINUTE) return 20;
  if (remainingMs >= 60 * MS_PER_MINUTE) return 40;
  return maxDiscountPercent;
}

export function roundToThousand(amount: number): number {
  return Math.round(amount / 1000) * 1000;
}

/**
 * Đơn giá (int VNĐ) tại thời điểm hiện tại, hoặc null nếu hết giờ.
 */
export function unitPriceFor(
  deal: DealPricingInput,
  remainingMs: number,
): number | null {
  const discount = discountPercentFor(
    remainingMs,
    deal.maxDiscountPercent ?? DEFAULT_MAX_DISCOUNT,
  );
  if (discount === null) return null;
  const discounted = roundToThousand(
    deal.originalPrice * (1 - discount / 100),
  );
  return Math.max(discounted, deal.minPrice);
}

/** Hoa hồng sàn, làm tròn VNĐ. Rate mặc định 10%; quán trong
 * Giai đoạn 1 (2 tháng đầu) chỉ chịu 5% — xem commissionRateFor. */
export function commissionFor(
  totalLockedPrice: number,
  rate: number = 0.1,
): number {
  return Math.round(totalLockedPrice * rate);
}

// ---------------------------------------------------------------------------
// Gói Túi + Phí (10/2026) — biểu phí gian hàng theo giai đoạn + hoa hồng
// theo tuổi quán. "Tháng" tính tròn 30 ngày để server và app khớp nhau:
//   Giai đoạn 1: tuổi < 60 ngày  → phí 0đ, hoa hồng 5%
//   Giai đoạn 2: 60 ≤ tuổi < 180 → phí 99.000đ/tháng, hoa hồng 10%
//   Giai đoạn 3: tuổi ≥ 180 ngày → phí 149.000đ/tháng, hoa hồng 10%
// Quán cũ không có createdAt được tính như Giai đoạn 3 (mức chuẩn).
// ---------------------------------------------------------------------------

export const FEE_STAGE1_DAYS = 60;
export const FEE_STAGE2_DAYS = 180;
export const FEE_STAGE2_AMOUNT = 99000;
export const FEE_STAGE3_AMOUNT = 149000;

export function feeStageFor(
  createdAtMs: number | null,
  nowMs: number,
): 1 | 2 | 3 {
  if (createdAtMs === null) return 3;
  const ageDays = (nowMs - createdAtMs) / 86400000;
  if (ageDays < FEE_STAGE1_DAYS) return 1;
  if (ageDays < FEE_STAGE2_DAYS) return 2;
  return 3;
}

export function feeAmountForStage(stage: 1 | 2 | 3): number {
  if (stage === 2) return FEE_STAGE2_AMOUNT;
  if (stage === 3) return FEE_STAGE3_AMOUNT;
  return 0;
}

export function commissionRateFor(
  createdAtMs: number | null,
  nowMs: number,
): number {
  return feeStageFor(createdAtMs, nowMs) === 1 ? 0.05 : 0.1;
}
