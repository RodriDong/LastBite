/**
 * Phase 3 — Deals: validation thuần (không phụ thuộc Admin SDK) cho
 * createDeal / pauseDeal. Dùng chung bởi index.ts và unit test.
 *
 * Xem docs/backend-contract.md §2.4.
 */

import { ApiError } from "./errors";
import { roundToThousand } from "./pricing";

export interface ValidatedDealInput {
  storeId: string;
  title: string;
  description: string;
  icon: string;
  category: string;
  originalPrice: number; // int, VNĐ — với túi = giá trị thật khai báo
  minPrice: number; // int, VNĐ — giá sàn (với túi = bagPrice)
  maxDiscountPercent: number; // int, 1..90 (với túi = 50)
  totalQty: number; // int, >= 1 — với túi = số túi
  saleEndAtMs: number; // epoch ms (UTC)
  pickupWindow: string;
  pickupSlots: string[];
  isGift: boolean;
  // Gói Túi + Phí (10/2026): 'bag' = túi bất ngờ (giá cố định 50%),
  // 'retail' = bán lẻ từng món (thang giảm theo giờ như cũ).
  dealType: "bag" | "retail";
  originalValue: number; // int, VNĐ — giá trị thật của túi (retail: = originalPrice)
  bagPrice: number; // int, VNĐ — giá bán túi (retail: 0)
  possibleCategories: string[]; // nhóm món có thể có trong túi
  allergyNote: string; // ghi chú dị ứng (túi), tối đa 200 ký tự
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
  // Túi mới gửi originalValue; fallback để client chỉ gửi 1 trong 2
  // vẫn qua được bước validate giá gốc bên dưới.
  const originalPrice =
    d.originalPrice !== undefined ? d.originalPrice : d.originalValue;
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

  // Gói Túi + Phí (10/2026): loại deal + giá túi.
  // Client mới gửi originalValue; client cũ (retail) chỉ gửi
  // originalPrice nên originalValue fallback về originalPrice.
  const dealType = d.dealType === "bag" ? "bag" : "retail";
  const rawValue = d.originalValue !== undefined ? d.originalValue : originalPrice;
  if (dealType === "bag") {
    if (isGift) {
      if (!isInt(rawValue) || rawValue !== 0) {
        throw invalid("Túi tặng phải có giá trị thật = 0.");
      }
    } else if (!isInt(rawValue) || rawValue <= 0) {
      throw invalid("Giá trị thật của túi phải là số nguyên dương (VNĐ).");
    }
  }
  const originalValue = dealType === "bag" ? (rawValue as number) : originalPrice;
  const bagPrice =
    dealType === "bag"
      ? isGift
        ? 0
        : roundToThousand(originalValue * 0.5)
      : 0;

  let possibleCategories: string[] = [];
  if (dealType === "bag") {
    if (
      !Array.isArray(d.possibleCategories) ||
      d.possibleCategories.length === 0 ||
      !d.possibleCategories.every((c) => typeof c === "string")
    ) {
      throw invalid("Túi cần chọn ít nhất 1 nhóm món có thể có.");
    }
    const seen = new Set<string>();
    for (const c of d.possibleCategories as string[]) {
      const t = c.trim();
      if (!DEAL_CATEGORIES.includes(t)) {
        throw invalid(`Nhóm món trong túi không hợp lệ: ${t}.`);
      }
      seen.add(t);
    }
    possibleCategories = [...seen];
  }
  const allergyNoteRaw = asString(d.allergyNote)?.trim() ?? "";
  if (allergyNoteRaw.length > 200) {
    throw invalid("Ghi chú dị ứng tối đa 200 ký tự.");
  }
  const allergyNote = dealType === "bag" ? allergyNoteRaw : "";

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
    // Túi: giá gốc trên doc = giá trị thật (để originalTotal và
    // savedMoney tính đúng); giá bán = bagPrice, giảm cố định 50%.
    category: dealType === "bag" ? possibleCategories[0] : category,
    originalPrice: dealType === "bag" ? originalValue : originalPrice,
    minPrice: dealType === "bag" ? bagPrice : minPrice,
    maxDiscountPercent: dealType === "bag" ? 50 : maxDiscountPercent,
    totalQty,
    saleEndAtMs,
    pickupWindow,
    pickupSlots,
    isGift,
    dealType,
    originalValue,
    bagPrice,
    possibleCategories,
    allergyNote,
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
