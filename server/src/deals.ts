/**
 * Phase 3 — Deals: validation thuần (không phụ thuộc Admin SDK) cho
 * createDeal / pauseDeal. Dùng chung bởi index.ts và unit test.
 *
 * Xem docs/backend-contract.md §2.4.
 */

import { ApiError } from "./errors";

export interface ValidatedDealInput {
  storeId: string;
  title: string;
  description: string;
  icon: string;
  category: string;
  originalPrice: number; // int, VNĐ
  minPrice: number; // int, VNĐ — giá sàn
  maxDiscountPercent: number; // int, 1..90
  totalQty: number; // int, >= 1
  saleEndAtMs: number; // epoch ms (UTC)
  pickupWindow: string;
  pickupSlots: string[];
  isGift: boolean;
}

export const DEFAULT_ICON = "📦";
export const DEFAULT_CATEGORY = "Khác";
export const DEFAULT_MAX_DISCOUNT = 60;
export const MAX_TITLE_LENGTH = 120;

/**
 * Danh mục deal chốt cứng (Phase 9) — khớp DealCategories phía app
 * (lib/models/mock_data.dart) và bộ lọc ở trang chủ buyer. Deal cũ có
 * category ngoài danh sách này vẫn đọc hiển thị bình thường; chỉ chặn
 * khi TẠO deal mới.
 */
export const DEAL_CATEGORIES = [
  "Bánh ngọt",
  "Cơm",
  "Bún phở",
  "Đồ uống",
  "Hoa quả",
  "Rau củ",
  "Pizza",
  "Món chay",
  "Khác",
];

function isInt(n: unknown): n is number {
  return typeof n === "number" && Number.isInteger(n);
}

function asString(v: unknown): string | null {
  return typeof v === "string" ? v : null;
}

function invalid(msg: string): ApiError {
  return new ApiError("invalid-argument", msg);
}

/**
 * Validate payload của callable createDeal. Ném ApiError(invalid-argument)
 * với message tiếng Việt khi dữ liệu không đạt.
 */
export function validateCreateDealInput(data: unknown): ValidatedDealInput {
  if (typeof data !== "object" || data === null) {
    throw invalid("Dữ liệu deal không hợp lệ.");
  }
  const d = data as Record<string, unknown>;

  const storeId = asString(d.storeId)?.trim();
  if (!storeId) throw invalid("Thiếu storeId.");

  const title = asString(d.title)?.trim();
  if (!title) throw invalid("Tên deal không được để trống.");
  if (title.length > MAX_TITLE_LENGTH) {
    throw invalid(`Tên deal tối đa ${MAX_TITLE_LENGTH} ký tự.`);
  }

  const description = asString(d.description)?.trim() ?? "";
  const icon = asString(d.icon)?.trim() || DEFAULT_ICON;
  const category = asString(d.category)?.trim() || DEFAULT_CATEGORY;
  if (!DEAL_CATEGORIES.includes(category)) {
    throw invalid(
      `Danh mục không hợp lệ. Chỉ chấp nhận: ${DEAL_CATEGORIES.join(", ")}.`,
    );
  }

  const isGift = d.isGift === true;
  const originalPrice = d.originalPrice;
  if (isGift) {
    if (!isInt(originalPrice) || originalPrice !== 0) {
      throw invalid("Suất tặng phải có giá gốc = 0.");
    }
  } else if (!isInt(originalPrice) || originalPrice <= 0) {
    throw invalid("Giá gốc phải là số nguyên dương (VNĐ).");
  }

  const minPrice = d.minPrice;
  if (isGift) {
    if (!isInt(minPrice) || minPrice !== 0) {
      throw invalid("Suất tặng phải có giá sàn = 0.");
    }
  } else if (!isInt(minPrice) || minPrice < 0 || minPrice > originalPrice) {
    throw invalid("Giá sàn phải là số nguyên, 0 ≤ giá sàn ≤ giá gốc.");
  }

  const maxDiscountPercent =
    d.maxDiscountPercent === undefined ? DEFAULT_MAX_DISCOUNT : d.maxDiscountPercent;
  if (
    !isInt(maxDiscountPercent) ||
    maxDiscountPercent <= 0 ||
    maxDiscountPercent > 90
  ) {
    throw invalid("Mức giảm giá tối đa phải từ 1 đến 90%.");
  }

  const totalQty = d.totalQty;
  if (!isInt(totalQty) || totalQty < 1) {
    throw invalid("Số lượng phần phải ≥ 1.");
  }

  const saleEndAtRaw = asString(d.saleEndAt);
  const saleEndAtMs = saleEndAtRaw ? Date.parse(saleEndAtRaw) : NaN;
  if (!saleEndAtRaw || Number.isNaN(saleEndAtMs)) {
    throw invalid("saleEndAt phải là chuỗi thời gian ISO hợp lệ.");
  }
  if (saleEndAtMs <= Date.now()) {
    throw invalid("Giờ kết thúc bán phải ở tương lai.");
  }

  const pickupWindow = asString(d.pickupWindow)?.trim() ?? "";

  let pickupSlots: string[] = [];
  if (d.pickupSlots !== undefined) {
    if (
      !Array.isArray(d.pickupSlots) ||
      !d.pickupSlots.every((s) => typeof s === "string")
    ) {
      throw invalid("pickupSlots phải là mảng chuỗi.");
    }
    pickupSlots = (d.pickupSlots as string[])
      .map((s) => s.trim())
      .filter((s) => s.length > 0);
  }

  return {
    storeId,
    title,
    description,
    icon,
    category,
    originalPrice,
    minPrice,
    maxDiscountPercent,
    totalQty,
    saleEndAtMs,
    pickupWindow,
    pickupSlots,
    isGift,
  };
}

export interface ValidatedPauseDealInput {
  dealId: string;
  paused: boolean;
}

/** Validate payload của callable pauseDeal. */
export function validatePauseDealInput(data: unknown): ValidatedPauseDealInput {
  if (typeof data !== "object" || data === null) {
    throw invalid("Dữ liệu không hợp lệ.");
  }
  const d = data as Record<string, unknown>;

  const dealId = asString(d.dealId)?.trim();
  if (!dealId) throw invalid("Thiếu dealId.");

  if (typeof d.paused !== "boolean") {
    throw invalid("paused phải là true/false.");
  }

  return { dealId, paused: d.paused };
}

/**
 * Phân loại deal active cần chuyển trạng thái (dùng cho expireDeals).
 * Trả về 'expired' | 'soldout' | null (giữ nguyên).
 */
export function classifyActiveDeal(
  saleEndAtMs: number,
  remainingQty: number,
  nowMs: number,
): "expired" | "soldout" | null {
  if (saleEndAtMs <= nowMs) return "expired";
  if (remainingQty <= 0) return "soldout";
  return null;
}
