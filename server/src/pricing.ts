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

/** Hoa hồng sàn 10%, làm tròn VNĐ. */
export function commissionFor(totalLockedPrice: number): number {
  return Math.round(totalLockedPrice * 0.1);
}
