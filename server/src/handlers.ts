/**
 * Toàn bộ logic nghiệp vụ của LastBite — port nguyên vẹn từ Cloud Functions
 * (functions/src/index.ts) sang API server độc lập. Khác biệt duy nhất:
 *  - Nhận (AuthContext, data) thay cho CallableRequest: uid/claims lấy từ
 *    Firebase ID token do guard.ts xác thực.
 *  - Ném ApiError thay HttpsError (cùng bộ mã lỗi).
 *
 * Xem docs/backend-contract.md — hợp đồng nghiệp vụ không đổi.
 */
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { put as blobPut } from "@vercel/blob";
import { db as getDb, auth } from "./admin";
import type { AuthContext } from "./guard";
import { ApiError } from "./errors";
import {
  DEAL_CATEGORIES,
  validateCreateDealInput,
  validatePauseDealInput,
  classifyActiveDeal,
} from "./deals";
import {
  validateCreateOrderInput,
  validateCancelOrderInput,
  validateConfirmPickupInput,
  generatePickupCodeCandidate,
  dailyStatsKey,
} from "./orders";
import {
  unitPriceFor,
  discountPercentFor,
  commissionFor,
  feeStageFor,
  feeAmountForStage,
  commissionRateFor,
} from "./pricing";
import { notifyUser } from "./notify";

// ---------------------------------------------------------------------------
// Bootstrap — thay cho Auth trigger onUserCreate (Firebase không bắn
// trigger ra hệ thống ngoài). App gọi POST /api/bootstrap ngay sau đăng ký
// và mỗi lần đăng nhập; tạo users/{uid} nếu chưa có (idempotent).
// Tiện thể "quét lười" deal hết hạn (thay scheduled expireDeals).
// ---------------------------------------------------------------------------

export async function bootstrap(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const ref = db.doc(`users/${ctx.uid}`);
  const snap = await ref.get();
  let created = false;
  if (!snap.exists) {
    const bodyName =
      typeof (data as { displayName?: unknown })?.displayName === "string"
        ? ((data as { displayName: string }).displayName ?? "")
        : "";
    await ref.set({
      email: ctx.token.email ?? "",
      displayName: bodyName || (ctx.token.name ?? ""),
      phone: null,
      greenPoints: 0,
      rescuedMeals: 0,
      savedMoney: 0,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    created = true;
  }
  await sweepExpiredDeals();
  return { ok: true, created };
}

/**
 * Quét lười: deal active mà hết giờ -> expired, hết hàng -> soldout.
 * Giới hạn 25 deal/lần gọi để không làm chậm request. Thay cho scheduled
 * function expireDeals (Vercel miễn phí không chạy cron dày được).
 */
export async function sweepExpiredDeals(): Promise<{ swept: number }> {
  const db = getDb();
  const snap = await db
    .collection("deals")
    .where("status", "==", "active")
    .limit(25)
    .get();
  const now = Date.now();
  const batch = db.batch();
  let swept = 0;
  snap.forEach((doc) => {
    const d = doc.data();
    const endMs = (d.saleEndAt as Timestamp | undefined)?.toMillis() ?? 0;
    const next = classifyActiveDeal(endMs, d.remainingQty as number, now);
    if (next) {
      batch.update(doc.ref, {
        status: next,
        updatedAt: FieldValue.serverTimestamp(),
      });
      swept++;
    }
  });
  if (swept > 0) await batch.commit();
  return { swept };
}

async function getOwnedStore(
  uid: string,
  storeId: string,
): Promise<FirebaseFirestore.DocumentData> {
  const db = getDb();
  const snap = await db.doc(`stores/${storeId}`).get();
  if (!snap.exists) {
    throw new ApiError("not-found", "Không tìm thấy cửa hàng.");
  }
  const data = snap.data() as FirebaseFirestore.DocumentData;
  if (data.ownerUid !== uid) {
    throw new ApiError(
      "permission-denied",
      "Bạn không sở hữu cửa hàng này.",
    );
  }
  return data;
}

async function pickUniquePickupCode(): Promise<string> {
  const db = getDb();
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = generatePickupCodeCandidate();
    const dup = await db
      .collection("orders")
      .where("pickupCode", "==", code)
      .where("status", "==", "PENDING")
      .limit(1)
      .get();
    if (dup.empty) return code;
  }
  throw new ApiError("internal", "Không sinh được mã nhận hàng. Thử lại.");
}

/**
 * Tự đăng ký làm seller (Phase 10) — user tự nâng quyền cho CHÍNH
 * mình: app gọi ngay sau khi đăng ký với vai trò "Người bán" (hoặc
 * khi đăng nhập mà chọn vai trò này). Khác grantSellerRole (admin
 * cấp cho uid bất kỳ): ở đây uid lấy từ token, không nhận tham số
 * uid nên không thể nâng quyền hộ người khác. Idempotent: gọi lại
 * khi đã là seller thì chỉ đảm bảo claim + bỏ qua tạo store.
 */
export async function becomeSeller(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;
  const storeName =
    typeof d.storeName === "string" ? d.storeName.trim() : "";
  if (storeName.length === 0 || storeName.length > 80) {
    throw new ApiError(
      "invalid-argument",
      "Tên cửa hàng phải từ 1 đến 80 ký tự.",
    );
  }

  // Gộp claim cũ (nếu có) rồi thêm seller: true — không ghi đè mù.
  const user = await auth().getUser(ctx.uid);
  await auth().setCustomUserClaims(ctx.uid, {
    ...(user.customClaims ?? {}),
    seller: true,
  });

  const storeRef = db.doc(`stores/${ctx.uid}`);
  const storeSnap = await storeRef.get();
  let created = false;
  if (!storeSnap.exists) {
    await storeRef.set({
      ownerUid: ctx.uid,
      name: storeName,
      address: "",
      location: null,
      phone: null,
      rating: 0,
      ratingCount: 0,
      isApproved: true,
      openHours: null,
      // Phí duy trì gian hàng 3 giai đoạn (Gói Túi + Phí): quán mới
      // được MIỄN PHÍ 2 tháng đầu (Giai đoạn 1), hạn 60 ngày, gia hạn
      // ở menu quán. Phí giả lập, không cần admin duyệt.
      feeExpiresAt: Timestamp.fromMillis(Date.now() + 60 * 24 * 3600 * 1000),
      feeStatus: "active",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await db.collection(`stores/${ctx.uid}/feePayments`).add({
      amount: 0,
      months: 2,
      method: "fake",
      note: "Giai đoạn 1 - Miễn phí 2 tháng đầu",
      createdAt: FieldValue.serverTimestamp(),
    });
    created = true;
  }
  return { ok: true, created };
}

export async function grantSellerRole(_ctx: AuthContext, data: unknown) {  const db = getDb();
  const { uid, storeName } = data as {
    uid?: unknown;
    storeName?: unknown;
  };
  if (typeof uid !== "string" || uid.length === 0) {
    throw new ApiError("invalid-argument", "Thiếu uid.");
  }
  if (typeof storeName !== "string" || storeName.trim().length === 0) {
    throw new ApiError("invalid-argument", "Thiếu storeName.");
  }

  await auth().setCustomUserClaims(uid, { seller: true });

  const storeRef = db.doc(`stores/${uid}`);
  const storeSnap = await storeRef.get();
  if (!storeSnap.exists) {
    await storeRef.set({
      ownerUid: uid,
      name: storeName.trim(),
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
  }
  return { ok: true };
}

export async function createDeal(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const uid = ctx.uid;
  const input = validateCreateDealInput(data);
  const store = await getOwnedStore(uid, input.storeId);
  // Phí duy trì gian hàng (BMC): quán hết hạn duy trì thì không đăng
  // suất mới. Quán cũ chưa có feeExpiresAt được miễn (tương thích ngược).
  const feeExpMs =
    (store.feeExpiresAt as Timestamp | undefined)?.toMillis() ?? 0;
  if (feeExpMs !== 0 && feeExpMs <= Date.now()) {
    throw new ApiError(
      "failed-precondition",
      "Gian hàng đã hết hạn duy trì. Vui lòng gia hạn để đăng suất mới.",
    );
  }

  // Phase 8: ảnh deal tùy chọn (base64) -> Vercel Blob, cùng cơ chế
  // ảnh chứng nhận Phase 7. Không gửi ảnh thì imageUrl = null và app
  // hiển thị emoji như trước.
  let imageUrl: string | null = null;
  const rawImg = (data as Record<string, unknown> | null)?.imageBase64;
  if (typeof rawImg === "string" && rawImg.length > 0) {
    if (!process.env.BLOB_READ_WRITE_TOKEN) {
      throw new ApiError(
        "internal",
        "Máy chủ chưa cấu hình kho lưu ảnh (thiếu BLOB_READ_WRITE_TOKEN).",
      );
    }
    const img = decodeImageBase64(rawImg);
    const blob = await blobPut(`deals/${uid}/${Date.now()}.${img.ext}`, img.buf, {
      access: "public",
      contentType: img.contentType,
    });
    imageUrl = blob.url;
  }

  // Denormalize thông tin cửa hàng để client hiển thị nhanh (không query thêm).
  const location = store.location as
    | FirebaseFirestore.GeoPoint
    | null
    | undefined;

  const ref = await db.collection("deals").add({
    storeId: input.storeId,
    storeName: (store.name as string) ?? "",
    storeAddress: (store.address as string) ?? "",
    storeLat: location?.latitude ?? null,
    storeLng: location?.longitude ?? null,
    title: input.title,
    description: input.description,
    icon: input.icon,
    category: input.category,
    imageUrl,
    originalPrice: input.originalPrice,
    minPrice: input.minPrice,
    maxDiscountPercent: input.maxDiscountPercent,
    isGift: input.isGift,
    // Gói Túi + Phí: loại deal + giá túi + gợi ý trong túi.
    dealType: input.dealType,
    originalValue: input.originalValue,
    bagPrice: input.bagPrice,
    possibleCategories: input.possibleCategories,
    allergyNote: input.allergyNote,
    totalQty: input.totalQty,
    remainingQty: input.totalQty,
    saleEndAt: Timestamp.fromMillis(input.saleEndAtMs),
    pickupWindow: input.pickupWindow,
    pickupSlots: input.pickupSlots,
    status: "active",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { dealId: ref.id, imageUrl };
}

export async function pauseDeal(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const uid = ctx.uid;
  const { dealId, paused } = validatePauseDealInput(data);

  const dealRef = db.doc(`deals/${dealId}`);
  const snap = await dealRef.get();
  if (!snap.exists) {
    throw new ApiError("not-found", "Không tìm thấy deal.");
  }
  const deal = snap.data() as FirebaseFirestore.DocumentData;
  await getOwnedStore(uid, deal.storeId as string);

  const status = deal.status as string;
  if (status === "expired" || status === "soldout") {
    throw new ApiError(
      "failed-precondition",
      "Deal đã kết thúc, không thể bật/tắt.",
    );
  }
  const target = paused ? "paused" : "active";
  if (status !== target) {
    await dealRef.update({
      status: target,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  return { ok: true };
}

export async function createOrder(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const uid = ctx.uid;
  const input = validateCreateOrderInput(data);
  const voucherRaw = (data as Record<string, unknown> | null)?.voucherId;
  const voucherId = typeof voucherRaw === "string" ? voucherRaw.trim() : "";
  const pickupCode = await pickUniquePickupCode();

  const dealRef = db.doc(`deals/${input.dealId}`);
  const orderRef = db.collection("orders").doc();
  const userRef = db.doc(`users/${uid}`);
  const now = Date.now();
  const buyerName =
    typeof ctx.token.name === "string"
      ? (ctx.token.name as string)
      : "";

  const result = await db.runTransaction(async (txn) => {
    const dealSnap = await txn.get(dealRef);
    if (!dealSnap.exists) {
      throw new ApiError("not-found", "Không tìm thấy deal.");
    }
    const deal = dealSnap.data() as FirebaseFirestore.DocumentData;

    const saleEndAt = deal.saleEndAt as Timestamp | undefined;
    const saleEndAtMs = saleEndAt ? saleEndAt.toMillis() : 0;
    if (saleEndAtMs <= now) {
      throw new ApiError("failed-precondition", "Suất này đã kết thúc phiên bán.");
    }
    const status = deal.status as string;
    if (status !== "active") {
      throw new ApiError(
        "failed-precondition",
        status === "soldout" ? "Deal đã hết phần." : "Deal hiện không mở bán.",
      );
    }
    const remainingQty = deal.remainingQty as number;
    if (remainingQty < input.quantity) {
      throw new ApiError("failed-precondition", "Deal đã hết phần.");
    }
    const slots = (deal.pickupSlots as string[] | undefined) ?? [];
    if (slots.length > 0 && !slots.includes(input.pickupSlot)) {
      throw new ApiError(
        "invalid-argument",
        "Khung giờ nhận không thuộc deal này.",
      );
    }

    // Gói Túi + Phí: túi bán giá cố định 50% (bagPrice), KHÔNG chạy
    // thang giảm theo giờ. Bán lẻ giữ nguyên công thức cũ.
    const isBag = (deal.dealType as string) === "bag";
    let unitPrice: number | null;
    let discountPercent: number;
    if (isBag) {
      const bagPrice = deal.bagPrice as number | undefined;
      if (typeof bagPrice !== "number") {
        throw new ApiError("failed-precondition", "Túi này thiếu giá bán.");
      }
      unitPrice = bagPrice;
      discountPercent = (deal.isGift as boolean) === true ? 100 : 50;
    } else {
      const maxDiscount = (deal.maxDiscountPercent as number) ?? 60;
      unitPrice = unitPriceFor(
        {
          originalPrice: deal.originalPrice as number,
          minPrice: deal.minPrice as number,
          maxDiscountPercent: maxDiscount,
        },
        saleEndAtMs - now,
      );
      discountPercent = discountPercentFor(saleEndAtMs - now, maxDiscount) ?? 0;
    }
    if (unitPrice === null) {
      throw new ApiError("failed-precondition", "Suất này đã kết thúc phiên bán.");
    }
    const totalLockedPrice = unitPrice * input.quantity;
    const originalTotal = (deal.originalPrice as number) * input.quantity;
    // Voucher (bản Hoàn thiện): trừ thêm vào số tiền người mua trả.
    // Voucher do điểm đổi nên quán vẫn nhận đủ totalLockedPrice —
    // hoa hồng (confirmPickup) tính trên totalLockedPrice, không đổi.
    let voucherDiscount = 0;
    let voucherRef: FirebaseFirestore.DocumentReference | null = null;
    if (voucherId) {
      if ((deal.isGift as boolean) === true) {
        throw new ApiError(
          "failed-precondition",
          "Đơn tặng không dùng voucher.",
        );
      }
      voucherRef = db.doc(`users/${uid}/vouchers/${voucherId}`);
      const vSnap = await txn.get(voucherRef);
      if (!vSnap.exists) {
        throw new ApiError("not-found", "Không tìm thấy ưu đãi này.");
      }
      const v = vSnap.data() as FirebaseFirestore.DocumentData;
      if (v.status !== "unused") {
        throw new ApiError(
          "failed-precondition",
          "Ưu đãi này đã được dùng hoặc đã hết hiệu lực.",
        );
      }
      const expMs = (v.expiresAt as Timestamp | undefined)?.toMillis() ?? 0;
      if (expMs <= Date.now()) {
        throw new ApiError("failed-precondition", "Ưu đãi này đã hết hiệu lực.");
      }
      if (totalLockedPrice < ((v.minOrder as number) ?? 0)) {
        throw new ApiError(
          "failed-precondition",
          "Đơn chưa đạt giá trị tối thiểu của ưu đãi.",
        );
      }
      voucherDiscount = Math.min((v.amount as number) ?? 0, totalLockedPrice);
    }
    const amountPaid = totalLockedPrice - voucherDiscount;
    const newRemaining = remainingQty - input.quantity;

    txn.update(dealRef, {
      remainingQty: newRemaining,
      status: newRemaining === 0 ? "soldout" : "active",
      updatedAt: FieldValue.serverTimestamp(),
    });
    txn.set(orderRef, {
      dealId: input.dealId,
      storeId: deal.storeId as string,
      buyerId: uid,
      buyerName,
      // Denormalize để màn Đơn hàng hiển thị không cần query thêm.
      dealTitle: (deal.title as string) ?? "",
      dealIcon: (deal.icon as string) ?? "📦",
      storeName: (deal.storeName as string) ?? "",
      quantity: input.quantity,
      unitLockedPrice: unitPrice,
      totalLockedPrice,
      originalTotal,
      voucherId: voucherId || null,
      voucherDiscount,
      amountPaid,
      pickupCode,
      pickupSlot: input.pickupSlot,
      status: "PENDING",
      paymentStatus: (deal.isGift === true) ? "PAID" : "UNPAID",
      paymentMethod: (deal.isGift === true) ? "gift" : input.paymentMethod,
      commissionAmount: 0,
      saleEndAt: deal.saleEndAt as Timestamp,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (voucherRef) {
      txn.update(voucherRef, {
        status: "used",
        usedOrderId: orderRef.id,
        usedAt: FieldValue.serverTimestamp(),
      });
    }
    txn.set(
      userRef,
      {
        savedMoney: FieldValue.increment(originalTotal - amountPaid),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return {
      orderId: orderRef.id,
      pickupCode,
      unitLockedPrice: unitPrice,
      totalLockedPrice,
      amountPaid,
      voucherDiscount,
      paymentMethod: input.paymentMethod,
      discountPercent,
      saleEndAt: new Date(saleEndAtMs).toISOString(),
      storeId: deal.storeId as string,
      dealTitle: deal.title as string,
    };
  });
  await notifyUser(result.storeId, {
    type: "order_new",
    title: "Đơn mới cần chuẩn bị",
    body: `Khách vừa đặt ${result.dealTitle} — mã nhận hàng ${result.pickupCode}.`,
    orderId: result.orderId,
  });
  return result;
}

export async function cancelOrder(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const uid = ctx.uid;
  const { orderId } = validateCancelOrderInput(data);
  const orderRef = db.doc(`orders/${orderId}`);
  let notifyStoreId = "";
  let notifyDealTitle = "";

  await db.runTransaction(async (txn) => {
    const snap = await txn.get(orderRef);
    if (!snap.exists) {
      throw new ApiError("not-found", "Không tìm thấy đơn hàng.");
    }
    const order = snap.data() as FirebaseFirestore.DocumentData;
    notifyStoreId = order.storeId as string;
    notifyDealTitle = order.dealTitle as string;
    if (order.buyerId !== uid) {
      throw new ApiError(
        "permission-denied",
        "Đây không phải đơn hàng của bạn.",
      );
    }
    if (order.status !== "PENDING") {
      throw new ApiError(
        "failed-precondition",
        "Chỉ hủy được đơn đang chờ lấy.",
      );
    }

    const dealRef = db.doc(`deals/${order.dealId as string}`);
    const dealSnap = await txn.get(dealRef);
    if (dealSnap.exists) {
      const deal = dealSnap.data() as FirebaseFirestore.DocumentData;
      const patch: Record<string, unknown> = {
        remainingQty:
          (deal.remainingQty as number) + (order.quantity as number),
        updatedAt: FieldValue.serverTimestamp(),
      };
      const endMs = (deal.saleEndAt as Timestamp | undefined)?.toMillis() ?? 0;
      if (deal.status === "soldout" && endMs > Date.now()) {
        patch.status = "active";
      }
      txn.update(dealRef, patch);
    }

    const cancelPatch: Record<string, unknown> = {
      status: "CANCELLED",
      cancelledAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    // Giả lập hoàn tiền: đơn đã trả (fake) thì hủy = hoàn tiền (fake),
    // không có tiền thật di chuyển.
    if (order.paymentStatus === "PAID") {
      cancelPatch.paymentStatus = "REFUNDED";
      cancelPatch.refundedAt = FieldValue.serverTimestamp();
    }
    txn.update(orderRef, cancelPatch);
    txn.set(
      db.doc(`users/${uid}`),
      {
        savedMoney: FieldValue.increment(
          -(
            (order.originalTotal as number) -
            ((order.amountPaid as number | undefined) ??
              ((order.totalLockedPrice as number) -
                ((order.voucherDiscount as number | undefined) ?? 0)))
          ),
        ),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    // Voucher: trả lại trạng thái chưa dùng để khách dùng cho đơn khác.
    if (order.voucherId) {
      const vRef = db.doc(`users/${uid}/vouchers/${order.voucherId as string}`);
      const vSnap = await txn.get(vRef);
      if (vSnap.exists) {
        const v = vSnap.data() as FirebaseFirestore.DocumentData;
        if (v.status === "used" && v.usedOrderId === orderRef.id) {
          txn.update(vRef, {
            status: "unused",
            usedOrderId: null,
            usedAt: null,
          });
        }
      }
    }
  });
  await notifyUser(notifyStoreId, {
    type: "order_cancelled",
    title: "Khách vừa hủy đơn",
    body: `Đơn ${notifyDealTitle} đã được hủy — suất đã trả lại quầy.`,
  });
  return { ok: true };
}

export async function confirmPickup(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const uid = ctx.uid;
  const { pickupCode } = validateConfirmPickupInput(data);

  const pending = await db
    .collection("orders")
    .where("pickupCode", "==", pickupCode)
    .where("status", "==", "PENDING")
    .limit(1)
    .get();
  if (pending.empty) {
    const any = await db
      .collection("orders")
      .where("pickupCode", "==", pickupCode)
      .limit(1)
      .get();
    if (any.empty) {
      throw new ApiError("not-found", "Không tìm thấy mã đơn chờ nhận!");
    }
    throw new ApiError(
      "failed-precondition",
      "Đơn này đã được xử lý trước đó.",
    );
  }
  const orderRef = pending.docs[0].ref;

  const result = await db.runTransaction(async (txn) => {
    const snap = await txn.get(orderRef);
    if (!snap.exists) {
      throw new ApiError("not-found", "Không tìm thấy đơn hàng.");
    }
    const order = snap.data() as FirebaseFirestore.DocumentData;
    if (order.status !== "PENDING") {
      throw new ApiError(
        "failed-precondition",
        "Đơn này đã được xử lý trước đó.",
      );
    }
    const storeId = order.storeId as string;
    const storeSnap = await txn.get(db.doc(`stores/${storeId}`));
    if (!storeSnap.exists || storeSnap.data()?.ownerUid !== uid) {
      throw new ApiError(
        "permission-denied",
        "Đơn này không thuộc cửa hàng của bạn.",
      );
    }

    if (order.paymentStatus !== "PAID") {
      throw new ApiError(
        "failed-precondition",
        "Đơn chưa được thanh toán. Khách cần thanh toán trước khi nhận hàng.",
      );
    }
    const total = order.totalLockedPrice as number;
    const qty = order.quantity as number;
    // Gói Túi + Phí: hoa hồng theo tuổi quán lúc xác nhận đơn —
    // Giai đoạn 1 (2 tháng đầu) chỉ 5%, từ Giai đoạn 2 trở đi 10%.
    const storeCreatedMs =
      (storeSnap.data()?.createdAt as Timestamp | undefined)?.toMillis() ??
      null;
    const commission = commissionFor(
      total,
      commissionRateFor(storeCreatedMs, Date.now()),
    );

    txn.update(orderRef, {
      status: "COMPLETED",
      commissionAmount: commission,
      completedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    txn.set(
      db.doc(`stores/${storeId}/dailyStats/${dailyStatsKey()}`),
      {
        revenue: FieldValue.increment(total),
        orders: FieldValue.increment(1),
        commission: FieldValue.increment(commission),
        rescuedMeals: FieldValue.increment(qty),
      },
      { merge: true },
    );
    txn.set(
      db.doc(`users/${order.buyerId as string}`),
      {
        greenPoints: FieldValue.increment(25),
        rescuedMeals: FieldValue.increment(qty),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return {
      orderId: orderRef.id,
      totalLockedPrice: total,
      commissionAmount: commission,
      buyerId: order.buyerId as string,
    };
  });
  await notifyUser(result.buyerId, {
    type: "order_completed",
    title: "Đã nhận hàng, cảm ơn bạn!",
    body: "+25 điểm xanh đã cộng vào tài khoản của bạn.",
    orderId: result.orderId,
  });
  return result;
}


// ---------------------------------------------------------------------------
// Phase 6 — Hồ sơ cửa hàng + Đánh giá
// ---------------------------------------------------------------------------

/** Chuỗi tùy chọn trong payload: null nếu không gửi lên. */
function optString(
  data: Record<string, unknown>,
  key: string,
  max: number,
): string | null {
  const v = data[key];
  if (v === undefined || v === null) return null;
  if (typeof v !== "string") {
    throw new ApiError("invalid-argument", `Trường ${key} phải là chuỗi.`);
  }
  const t = v.trim();
  if (t.length > max) {
    throw new ApiError(
      "invalid-argument",
      `Trường ${key} tối đa ${max} ký tự.`,
    );
  }
  return t;
}

/**
 * Seller cập nhật hồ sơ cửa hàng của chính mình (stores/{uid}).
 * Chỉ nhận các trường gửi lên; ít nhất 1 trường hợp lệ.
 */
export async function updateStoreProfile(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;
  const patch: Record<string, unknown> = {};

  const name = optString(d, "name", 80);
  if (name !== null) {
    if (name.length === 0) {
      throw new ApiError(
        "invalid-argument",
        "Tên cửa hàng không được để trống.",
      );
    }
    patch.name = name;
  }
  const address = optString(d, "address", 200);
  if (address !== null) patch.address = address;
  const phone = optString(d, "phone", 20);
  if (phone !== null) {
    if (phone !== "" && !/^[0-9+ ]+$/.test(phone)) {
      throw new ApiError(
        "invalid-argument",
        "Số điện thoại chỉ gồm số, dấu + và khoảng trắng.",
      );
    }
    patch.phone = phone === "" ? null : phone;
  }
  const openHours = optString(d, "openHours", 60);
  if (openHours !== null) patch.openHours = openHours === "" ? null : openHours;

  if (Object.keys(patch).length === 0) {
    throw new ApiError(
      "invalid-argument",
      "Không có trường nào để cập nhật.",
    );
  }

  const ref = db.doc(`stores/${ctx.uid}`);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new ApiError("not-found", "Không tìm thấy cửa hàng của bạn.");
  }
  if (snap.data()?.ownerUid !== ctx.uid) {
    throw new ApiError(
      "permission-denied",
      "Cửa hàng không thuộc về tài khoản này.",
    );
  }
  await ref.update({ ...patch, updatedAt: FieldValue.serverTimestamp() });
  return { ok: true };
}

/**
 * Buyer đánh giá 1 đơn COMPLETED của mình: 1 đơn = 1 đánh giá
 * (doc reviews/{orderId} — chống đánh giá trùng). Cập nhật điểm
 * trung bình của cửa hàng (stores.rating / ratingCount) cùng
 * transaction, và đánh dấu orders.reviewed để app ẩn nút đánh giá.
 */
export async function submitReview(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;

  const orderId = typeof d.orderId === "string" ? d.orderId.trim() : "";
  if (!orderId) {
    throw new ApiError("invalid-argument", "Thiếu orderId.");
  }
  const rating = d.rating;
  if (
    typeof rating !== "number" ||
    !Number.isInteger(rating) ||
    rating < 1 ||
    rating > 5
  ) {
    throw new ApiError(
      "invalid-argument",
      "Điểm đánh giá phải là số nguyên từ 1 đến 5.",
    );
  }
  const comment = optString(d, "comment", 500) ?? "";

  const orderRef = db.doc(`orders/${orderId}`);
  const reviewRef = db.doc(`reviews/${orderId}`);

  const result = await db.runTransaction(async (tx) => {
    const [ordSnap, reviewSnap] = await Promise.all([
      tx.get(orderRef),
      tx.get(reviewRef),
    ]);
    if (!ordSnap.exists) {
      throw new ApiError("not-found", "Không tìm thấy đơn hàng.");
    }
    const ord = ordSnap.data()!;
    if (ord.buyerId !== ctx.uid) {
      throw new ApiError(
        "permission-denied",
        "Chỉ người mua đơn này mới được đánh giá.",
      );
    }
    if (ord.status !== "COMPLETED") {
      throw new ApiError(
        "failed-precondition",
        "Chỉ đánh giá được đơn đã hoàn thành.",
      );
    }
    if (reviewSnap.exists) {
      throw new ApiError("already-exists", "Đơn này đã được đánh giá.");
    }
    const storeId = (ord.storeId as string) ?? "";
    const storeRef = db.doc(`stores/${storeId}`);
    const storeSnap = await tx.get(storeRef);

    tx.set(reviewRef, {
      orderId,
      storeId,
      dealId: (ord.dealId as string) ?? "",
      buyerUid: ctx.uid,
      buyerName: (ord.buyerName as string) ?? "",
      rating,
      comment,
      createdAt: FieldValue.serverTimestamp(),
    });

    let storeRating: number | null = null;
    let storeRatingCount: number | null = null;
    if (storeSnap.exists) {
      const sd = storeSnap.data()!;
      const prevCount =
        typeof sd.ratingCount === "number" ? sd.ratingCount : 0;
      const prevRating = typeof sd.rating === "number" ? sd.rating : 0;
      storeRatingCount = prevCount + 1;
      storeRating =
        Math.round(((prevRating * prevCount + rating) / storeRatingCount) * 100) /
        100;
      tx.update(storeRef, {
        rating: storeRating,
        ratingCount: storeRatingCount,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    tx.update(orderRef, { reviewed: true, reviewRating: rating });
    return { storeRating, storeRatingCount };
  });

  const ordSnap = await db.doc(`orders/${orderId}`).get();
  const ordData = ordSnap.data();
  if (ordData) {
    await notifyUser(ordData.storeId as string, {
      type: "review_new",
      title: "Quán có đánh giá mới",
      body: `Khách chấm ${rating}★ cho suất ${ordData.dealTitle ?? "của quán"}.`,
      orderId,
    });
  }
  return { ok: true, rating, ...result };
}

// ---------------------------------------------------------------------------
// Phase 7 — Giấy chứng nhận an toàn thực phẩm
// Seller nộp ảnh chứng nhận -> trạng thái "pending"; admin (chủ dự án)
// duyệt TAY trong Firebase Console bằng cách sửa stores.certStatus thành
// "approved" / "rejected" (+ certReviewNote). Ảnh lưu ở Vercel Blob vì
// Firebase Storage bị khóa sau gói Blaze; Firestore chỉ giữ URL + trạng
// thái. URL ảnh là công khai theo link (không đoán được) — đánh đổi đã
// chấp nhận cho phạm vi đồ án.
// ---------------------------------------------------------------------------

const CERT_MAX_BYTES = 2_500_000; // ~2,5MB sau nén phía app

/**
 * Giải mã + kiểm tra ảnh base64: chỉ nhận JPEG/PNG thật (theo chữ ký
 * file), tối đa CERT_MAX_BYTES. Dùng chung cho chứng nhận ATTP
 * (submitCertificate) và ảnh deal (createDeal).
 */
function decodeImageBase64(b64: string): {
  buf: Buffer;
  ext: string;
  contentType: string;
} {
  const buf = Buffer.from(b64, "base64");
  if (buf.length === 0) {
    throw new ApiError("invalid-argument", "Dữ liệu ảnh không hợp lệ.");
  }
  if (buf.length > CERT_MAX_BYTES) {
    throw new ApiError(
      "invalid-argument",
      "Ảnh quá lớn (tối đa khoảng 2,5MB). Hãy chọn ảnh nhỏ hơn.",
    );
  }
  const isJpeg = buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff;
  const isPng =
    buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47;
  if (!isJpeg && !isPng) {
    throw new ApiError("invalid-argument", "Chỉ nhận ảnh JPG hoặc PNG.");
  }
  return isJpeg
    ? { buf, ext: "jpg", contentType: "image/jpeg" }
    : { buf, ext: "png", contentType: "image/png" };
}

export async function submitCertificate(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;

  const b64 = typeof d.imageBase64 === "string" ? d.imageBase64 : "";
  if (!b64) {
    throw new ApiError("invalid-argument", "Thiếu dữ liệu ảnh (imageBase64).");
  }
  const { buf, ext, contentType } = decodeImageBase64(b64);

  const ref = db.doc(`stores/${ctx.uid}`);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new ApiError("not-found", "Không tìm thấy cửa hàng của bạn.");
  }
  if (snap.data()?.ownerUid !== ctx.uid) {
    throw new ApiError(
      "permission-denied",
      "Cửa hàng không thuộc về tài khoản này.",
    );
  }

  if (!process.env.BLOB_READ_WRITE_TOKEN) {
    throw new ApiError(
      "internal",
      "Máy chủ chưa cấu hình kho lưu ảnh (thiếu BLOB_READ_WRITE_TOKEN).",
    );
  }
  const blob = await blobPut(
    `certificates/${ctx.uid}/${Date.now()}.${ext}`,
    buf,
    { access: "public", contentType },
  );

  await ref.update({
    certUrl: blob.url,
    certStatus: "pending",
    certSubmittedAt: FieldValue.serverTimestamp(),
    certReviewedAt: FieldValue.delete(),
    certReviewNote: FieldValue.delete(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { ok: true, certUrl: blob.url, certStatus: "pending" };
}

// ---------------------------------------------------------------------------
// Bản Hoàn thiện 24/10/2026 — yêu thích, hồ sơ buyer, sửa deal,
// duyệt chứng nhận trong app, FCM token, đánh dấu đã đọc thông báo.
// ---------------------------------------------------------------------------

/**
 * Buyer bật/tắt yêu thích 1 quán (users/{uid}/favorites/{storeId}).
 * Ghi qua Admin SDK nên không cần mở quyền ghi cho client.
 */
export async function toggleFavorite(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;
  const storeId = typeof d.storeId === "string" ? d.storeId.trim() : "";
  const storeName = typeof d.storeName === "string" ? d.storeName.trim() : "";
  if (!storeId) {
    throw new ApiError("invalid-argument", "Thiếu storeId.");
  }
  const storeSnap = await db.doc(`stores/${storeId}`).get();
  if (!storeSnap.exists) {
    throw new ApiError("not-found", "Không tìm thấy cửa hàng.");
  }
  const favRef = db.doc(`users/${ctx.uid}/favorites/${storeId}`);
  const snap = await favRef.get();
  if (snap.exists) {
    await favRef.delete();
    return { favorited: false };
  }
  await favRef.set({
    storeId,
    storeName: storeName || ((storeSnap.data()?.name as string) ?? ""),
    createdAt: FieldValue.serverTimestamp(),
  });
  return { favorited: true };
}

/** Buyer đổi tên hiển thị (đồng bộ Auth displayName + users doc). */
export async function updateBuyerProfile(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;
  const name = typeof d.displayName === "string" ? d.displayName.trim() : "";
  if (name.length < 1 || name.length > 60) {
    throw new ApiError(
      "invalid-argument",
      "Tên hiển thị từ 1 đến 60 ký tự.",
    );
  }
  await db.doc(`users/${ctx.uid}`).set(
    { displayName: name, updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  return { ok: true };
}

/**
 * Seller sửa deal đang bán/tạm dừng: tên, mô tả, danh mục, ảnh.
 * Không cho sửa giá/số lượng/giờ bán (đã khóa theo đơn đang chờ) —
 * muốn đổi các trường đó thì tắt deal cũ và đăng deal mới.
 */
export async function updateDeal(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const uid = ctx.uid;
  const d = (data ?? {}) as Record<string, unknown>;
  const dealId = typeof d.dealId === "string" ? d.dealId.trim() : "";
  if (!dealId) {
    throw new ApiError("invalid-argument", "Thiếu dealId.");
  }
  const dealRef = db.doc(`deals/${dealId}`);
  const snap = await dealRef.get();
  if (!snap.exists) {
    throw new ApiError("not-found", "Không tìm thấy deal.");
  }
  const deal = snap.data() as FirebaseFirestore.DocumentData;
  await getOwnedStore(uid, deal.storeId as string);
  const status = deal.status as string;
  if (status !== "active" && status !== "paused") {
    throw new ApiError(
      "failed-precondition",
      "Chỉ sửa được deal đang bán hoặc đang tạm dừng.",
    );
  }
  const patch: Record<string, unknown> = {};
  if (d.title !== undefined) {
    const t = typeof d.title === "string" ? d.title.trim() : "";
    if (t.length < 1 || t.length > 100) {
      throw new ApiError("invalid-argument", "Tên món từ 1 đến 100 ký tự.");
    }
    patch.title = t;
  }
  if (d.description !== undefined) {
    patch.description = optString(d, "description", 500) ?? "";
  }
  if (d.category !== undefined) {
    const cat = typeof d.category === "string" ? d.category : "";
    if (!DEAL_CATEGORIES.includes(cat)) {
      throw new ApiError(
        "invalid-argument",
        `Danh mục không hợp lệ. Chỉ chấp nhận: ${DEAL_CATEGORIES.join(", ")}.`,
      );
    }
    patch.category = cat;
  }
  // Gói Túi + Phí: túi được sửa gợi ý trong túi + ghi chú dị ứng.
  // Deal lẻ gửi 2 trường này lên sẽ bị bỏ qua (không lỗi).
  if (deal.dealType === "bag") {
    if (d.possibleCategories !== undefined) {
      if (
        !Array.isArray(d.possibleCategories) ||
        d.possibleCategories.length === 0 ||
        !d.possibleCategories.every((c) => typeof c === "string")
      ) {
        throw new ApiError(
          "invalid-argument",
          "Túi cần chọn ít nhất 1 nhóm món có thể có.",
        );
      }
      const seen = new Set<string>();
      for (const c of d.possibleCategories as string[]) {
        const t = c.trim();
        if (!DEAL_CATEGORIES.includes(t)) {
          throw new ApiError(
            "invalid-argument",
            `Nhóm món trong túi không hợp lệ: ${t}.`,
          );
        }
        seen.add(t);
      }
      patch.possibleCategories = [...seen];
      patch.category = [...seen][0];
    }
    if (d.allergyNote !== undefined) {
      const note = typeof d.allergyNote === "string" ? d.allergyNote.trim() : "";
      if (note.length > 200) {
        throw new ApiError(
          "invalid-argument",
          "Ghi chú dị ứng tối đa 200 ký tự.",
        );
      }
      patch.allergyNote = note;
    }
  }
  const rawImg = d.imageBase64;
  if (typeof rawImg === "string" && rawImg.length > 0) {
    if (!process.env.BLOB_READ_WRITE_TOKEN) {
      throw new ApiError(
        "internal",
        "Máy chủ chưa cấu hình kho lưu ảnh (thiếu BLOB_READ_WRITE_TOKEN).",
      );
    }
    const img = decodeImageBase64(rawImg);
    const blob = await blobPut(`deals/${uid}/${Date.now()}.${img.ext}`, img.buf, {
      access: "public",
      contentType: img.contentType,
    });
    patch.imageUrl = blob.url;
  }
  if (Object.keys(patch).length === 0) {
    throw new ApiError("invalid-argument", "Chưa có gì để sửa.");
  }
  patch.updatedAt = FieldValue.serverTimestamp();
  await dealRef.update(patch);
  return { ok: true };
}

/**
 * Admin (chủ dự án, claim admin) duyệt chứng nhận ATTP ngay trong app,
 * thay cho việc sửa tay trong Console. Kèm thông báo cho seller.
 */
export async function reviewCertificate(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;
  const storeId = typeof d.storeId === "string" ? d.storeId.trim() : "";
  if (!storeId) {
    throw new ApiError("invalid-argument", "Thiếu storeId.");
  }
  if (typeof d.approved !== "boolean") {
    throw new ApiError("invalid-argument", "Thiếu approved (true/false).");
  }
  const note = optString(d, "note", 300) ?? "";
  const ref = db.doc(`stores/${storeId}`);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new ApiError("not-found", "Không tìm thấy cửa hàng.");
  }
  await ref.update({
    certStatus: d.approved ? "approved" : "rejected",
    certReviewNote: note,
    certReviewedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await notifyUser(storeId, {
    type: "cert_result",
    title: d.approved
      ? "Chứng nhận đã được duyệt"
      : "Chứng nhận chưa được duyệt",
    body: d.approved
      ? "Quán của bạn đã có huy hiệu “Đã kiểm chứng an toàn thực phẩm”."
      : `Lý do: ${note || "Ảnh chưa rõ ràng, vui lòng gửi lại."}`,
  });
  return { ok: true };
}

/** Lưu FCM token của thiết bị để server gửi push khi đơn đổi trạng thái. */
export async function saveFcmToken(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;
  const token = typeof d.token === "string" ? d.token.trim() : "";
  if (token.length < 10 || token.length > 500) {
    throw new ApiError("invalid-argument", "FCM token không hợp lệ.");
  }
  const platform =
    typeof d.platform === "string" ? d.platform : "android";
  await db.doc(`users/${ctx.uid}`).set(
    {
      fcmToken: token,
      fcmPlatform: platform,
      fcmUpdatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return { ok: true };
}

/** Đánh dấu đã đọc 1 thông báo (hoặc tất cả nếu không truyền id). */
export async function markNotificationsRead(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const uid = ctx.uid;
  const d = (data ?? {}) as Record<string, unknown>;
  const notificationId =
    typeof d.notificationId === "string" ? d.notificationId.trim() : "";
  if (notificationId) {
    const ref = db.doc(`notifications/${notificationId}`);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new ApiError("not-found", "Không tìm thấy thông báo.");
    }
    if ((snap.data()?.userId as string) !== uid) {
      throw new ApiError("permission-denied", "Không phải thông báo của bạn.");
    }
    await ref.update({ read: true });
    return { ok: true };
  }
  const qs = await db
    .collection("notifications")
    .where("userId", "==", uid)
    .where("read", "==", false)
    .limit(100)
    .get();
  const batch = db.batch();
  qs.docs.forEach((doc) => batch.update(doc.ref, { read: true }));
  await batch.commit();
  return { ok: true, marked: qs.size };
}

// ---------------------------------------------------------------------------
// exchangeVoucher — đổi điểm xanh lấy mã giảm giá (bản Hoàn thiện)
// ---------------------------------------------------------------------------
//
// Người mua dùng điểm xanh tích lũy (+25/đơn hoàn thành) để đổi voucher.
// Voucher nằm ở users/{uid}/vouchers (server ghi duy nhất, rules khóa
// write phía client) và được trừ ở createOrder, trả lại ở cancelOrder.
export const VOUCHER_TIERS: Record<
  string,
  { amount: number; minOrder: number; cost: number }
> = {
  V10K: { amount: 10000, minOrder: 30000, cost: 100 },
  V20K: { amount: 20000, minOrder: 50000, cost: 200 },
};

export async function exchangeVoucher(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;
  const tierKey = typeof d.tier === "string" ? d.tier : "";
  const tier = VOUCHER_TIERS[tierKey];
  if (!tier) {
    throw new ApiError("invalid-argument", "Gói ưu đãi không hợp lệ.");
  }
  const userRef = db.doc(`users/${ctx.uid}`);
  const voucherRef = db.collection(`users/${ctx.uid}/vouchers`).doc();
  await db.runTransaction(async (txn) => {
    const snap = await txn.get(userRef);
    const points = (snap.data()?.greenPoints as number) ?? 0;
    if (points < tier.cost) {
      throw new ApiError(
        "failed-precondition",
        "Bạn chưa đủ điểm xanh để đổi ưu đãi này.",
      );
    }
    txn.set(
      userRef,
      {
        greenPoints: FieldValue.increment(-tier.cost),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    txn.set(voucherRef, {
      tier: tierKey,
      amount: tier.amount,
      minOrder: tier.minOrder,
      cost: tier.cost,
      status: "unused",
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + 30 * 24 * 3600 * 1000),
      usedOrderId: null,
      usedAt: null,
    });
  });
  return {
    ok: true,
    voucherId: voucherRef.id,
    amount: tier.amount,
    minOrder: tier.minOrder,
  };
}

// ---------------------------------------------------------------------------
// confirmFakePayment — GIẢ LẬP cổng thanh toán (BMC: MoMo, VNPay,
// ZaloPay, PayOS). Không gọi SDK thật, không trừ tiền thật, không cần
// tài khoản merchant: chỉ chuyển đơn PENDING+UNPAID sang PAID để demo
// trọn luồng sàn (đặt -> trả -> nhận). Khi vận hành thật, thay hàm này
// bằng xác thực callback/webhook của cổng thanh toán.
// ---------------------------------------------------------------------------
export async function confirmFakePayment(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;
  const orderId = typeof d.orderId === "string" ? d.orderId.trim() : "";
  if (!orderId) {
    throw new ApiError("invalid-argument", "Thiếu orderId.");
  }
  const orderRef = db.doc(`orders/${orderId}`);
  await db.runTransaction(async (txn) => {
    const snap = await txn.get(orderRef);
    if (!snap.exists) {
      throw new ApiError("not-found", "Không tìm thấy đơn hàng.");
    }
    const order = snap.data() as FirebaseFirestore.DocumentData;
    if (order.buyerId !== ctx.uid) {
      throw new ApiError("permission-denied", "Đơn này không thuộc về bạn.");
    }
    if (order.status !== "PENDING") {
      throw new ApiError(
        "failed-precondition",
        "Đơn này đã được xử lý trước đó.",
      );
    }
    if (order.paymentStatus === "PAID") return;
    if (order.paymentStatus !== "UNPAID") {
      throw new ApiError(
        "failed-precondition",
        "Đơn này không ở trạng thái chờ thanh toán.",
      );
    }
    txn.update(orderRef, {
      paymentStatus: "PAID",
      paidAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { ok: true };
}

// ---------------------------------------------------------------------------
// Gói 2+3 (BMC) — doanh thu sàn + vận hành
// ---------------------------------------------------------------------------

export const SHOP_FEE_DAYS = 30;
export const PROMO_FEE_PER_DAY = 20000;

/// Gia hạn gian hàng (seller): +30 ngày kể từ hạn hiện tại (hoặc từ nay
/// nếu đã hết hạn). Phí giả lập, không cần admin duyệt.
/// Gói Túi + Phí: số tiền theo giai đoạn lúc gia hạn — Giai đoạn 1
/// đang miễn phí thì không cần gia hạn (báo lỗi để app hiện hạn miễn
/// phí); Giai đoạn 2 = 99.000đ, Giai đoạn 3 = 149.000đ.
export async function renewShopFee(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const storeRef = db.doc(`stores/${ctx.uid}`);
  const snap = await storeRef.get();
  if (!snap.exists) {
    throw new ApiError("not-found", "Chưa có gian hàng.");
  }
  const createdMs =
    (snap.data()?.createdAt as Timestamp | undefined)?.toMillis() ?? null;
  const stage = feeStageFor(createdMs, Date.now());
  if (stage === 1) {
    throw new ApiError(
      "failed-precondition",
      "Gian hàng đang trong 2 tháng miễn phí (Giai đoạn 1), chưa cần gia hạn.",
    );
  }
  const amount = feeAmountForStage(stage);
  const cur =
    (snap.data()?.feeExpiresAt as Timestamp | undefined)?.toMillis() ?? 0;
  const base = Math.max(Date.now(), cur);
  const next = Timestamp.fromMillis(base + SHOP_FEE_DAYS * 24 * 3600 * 1000);
  await storeRef.update({
    feeExpiresAt: next,
    feeStatus: "active",
    updatedAt: FieldValue.serverTimestamp(),
  });
  await db.collection(`stores/${ctx.uid}/feePayments`).add({
    amount,
    months: 1,
    method: "fake",
    note: `Gia hạn gian hàng (Giai đoạn ${stage})`,
    createdAt: FieldValue.serverTimestamp(),
  });
  return {
    ok: true,
    feeExpiresAt: new Date(next.toMillis()).toISOString(),
    stage,
    amount,
  };
}

/// Đăng ký quảng bá suất (seller, BMC "phí ưu tiên hiển thị"): 1 suất chỉ
/// có tối đa 1 yêu cầu pending/active. Admin duyệt mới lên trang chủ.
export async function requestPromotion(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;
  const dealId = typeof d.dealId === "string" ? d.dealId.trim() : "";
  const days = d.days;
  if (!dealId) {
    throw new ApiError("invalid-argument", "Thiếu dealId.");
  }
  if (days !== 1 && days !== 3 && days !== 7) {
    throw new ApiError("invalid-argument", "Chỉ hỗ trợ gói 1 / 3 / 7 ngày.");
  }
  const dealSnap = await db.doc(`deals/${dealId}`).get();
  if (!dealSnap.exists) {
    throw new ApiError("not-found", "Không tìm thấy suất.");
  }
  const deal = dealSnap.data() as FirebaseFirestore.DocumentData;
  if (deal.storeId !== ctx.uid) {
    throw new ApiError(
      "permission-denied",
      "Suất này không thuộc cửa hàng của bạn.",
    );
  }
  if (deal.status !== "active") {
    throw new ApiError("failed-precondition", "Chỉ quảng bá suất đang bán.");
  }
  const dup = await db
    .collection("promotions")
    .where("dealId", "==", dealId)
    .where("status", "in", ["pending", "active"])
    .limit(1)
    .get();
  if (!dup.empty) {
    throw new ApiError(
      "failed-precondition",
      "Suất này đã có yêu cầu quảng bá đang chờ hoặc đang chạy.",
    );
  }
  const ref = await db.collection("promotions").add({
    storeId: ctx.uid,
    dealId,
    days,
    fee: (days as number) * PROMO_FEE_PER_DAY,
    status: "pending",
    createdAt: FieldValue.serverTimestamp(),
  });
  return { ok: true, promotionId: ref.id };
}

/// Duyệt quảng bá (admin): duyệt -> chạy N ngày kể từ lúc duyệt, phí ghi
/// nhận là giả lập; từ chối -> ghi lý do + báo cho quán.
export async function reviewPromotion(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;
  const promotionId =
    typeof d.promotionId === "string" ? d.promotionId.trim() : "";
  const approve = d.approve === true;
  const note = typeof d.note === "string" ? d.note.trim() : "";
  if (!promotionId) {
    throw new ApiError("invalid-argument", "Thiếu promotionId.");
  }
  const ref = db.doc(`promotions/${promotionId}`);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new ApiError("not-found", "Không tìm thấy yêu cầu.");
  }
  const p = snap.data() as FirebaseFirestore.DocumentData;
  if (p.status !== "pending") {
    throw new ApiError("failed-precondition", "Yêu cầu này đã được xử lý.");
  }
  if (approve) {
    const days = (p.days as number) ?? 1;
    await ref.update({
      status: "active",
      startAt: FieldValue.serverTimestamp(),
      endAt: Timestamp.fromMillis(Date.now() + days * 24 * 3600 * 1000),
      feePaid: true,
      feeMethod: "fake",
      updatedAt: FieldValue.serverTimestamp(),
    });
    await notifyUser(p.storeId as string, {
      type: "promotion_approved",
      title: "Quảng bá đã được duyệt",
      body: `Suất của quán đang nổi bật trên trang chủ trong ${days} ngày.`,
    });
  } else {
    await ref.update({
      status: "rejected",
      reviewNote: note,
      updatedAt: FieldValue.serverTimestamp(),
    });
    await notifyUser(p.storeId as string, {
      type: "promotion_rejected",
      title: "Quảng bá chưa được duyệt",
      body: note || "Yêu cầu quảng bá chưa được duyệt.",
    });
  }
  return { ok: true };
}

/// Báo đã chuyển khoản hoa hồng (seller, BMC "hoa hồng % đơn thành công"):
/// số tiền không vượt công nợ còn lại (tổng hoa hồng dailyStats - tổng đã
/// duyệt). Tiền thật chuyển ngoài app, admin duyệt = xác nhận đã nhận.
export async function reportSettlement(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;
  const amount = d.amount;
  if (typeof amount !== "number" || !Number.isInteger(amount) || amount <= 0) {
    throw new ApiError("invalid-argument", "Số tiền đối soát không hợp lệ.");
  }
  const statsSnap = await db.collection(`stores/${ctx.uid}/dailyStats`).get();
  let recorded = 0;
  statsSnap.forEach((doc) => {
    recorded += (doc.data()?.commission as number) ?? 0;
  });
  const paidSnap = await db
    .collection(`stores/${ctx.uid}/settlements`)
    .where("status", "==", "approved")
    .get();
  let paid = 0;
  paidSnap.forEach((doc) => {
    paid += (doc.data()?.amount as number) ?? 0;
  });
  const owed = recorded - paid;
  if (amount > owed) {
    throw new ApiError(
      "failed-precondition",
      `Số tiền vượt công nợ còn lại (${owed}đ).`,
    );
  }
  const ref = await db.collection(`stores/${ctx.uid}/settlements`).add({
    amount,
    status: "pending",
    method: "fake",
    createdAt: FieldValue.serverTimestamp(),
  });
  return { ok: true, settlementId: ref.id, owed: owed - amount };
}

/// Duyệt đối soát (admin): duyệt -> trừ công nợ; từ chối -> ghi lý do.
export async function confirmSettlement(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;
  const storeId = typeof d.storeId === "string" ? d.storeId.trim() : "";
  const settlementId =
    typeof d.settlementId === "string" ? d.settlementId.trim() : "";
  const approve = d.approve === true;
  const note = typeof d.note === "string" ? d.note.trim() : "";
  if (!storeId || !settlementId) {
    throw new ApiError("invalid-argument", "Thiếu storeId/settlementId.");
  }
  const ref = db.doc(`stores/${storeId}/settlements/${settlementId}`);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new ApiError("not-found", "Không tìm thấy yêu cầu.");
  }
  const st = snap.data() as FirebaseFirestore.DocumentData;
  if (st.status !== "pending") {
    throw new ApiError("failed-precondition", "Yêu cầu này đã được xử lý.");
  }
  if (approve) {
    await ref.update({
      status: "approved",
      updatedAt: FieldValue.serverTimestamp(),
    });
    await notifyUser(storeId, {
      type: "settlement_approved",
      title: "Đối soát đã được duyệt",
      body: `Sàn đã xác nhận ${st.amount}đ hoa hồng.`,
    });
  } else {
    await ref.update({
      status: "rejected",
      reviewNote: note,
      updatedAt: FieldValue.serverTimestamp(),
    });
    await notifyUser(storeId, {
      type: "settlement_rejected",
      title: "Đối soát chưa được duyệt",
      body: note || "Yêu cầu đối soát chưa được duyệt.",
    });
  }
  return { ok: true };
}

/// Khiếu nại đơn đã nhận (buyer, BMC "đổi trả, xử lý khiếu nại").
export async function reportComplaint(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;
  const orderId = typeof d.orderId === "string" ? d.orderId.trim() : "";
  const reason = typeof d.reason === "string" ? d.reason.trim() : "";
  const note = typeof d.note === "string" ? d.note.trim() : "";
  if (!orderId || !reason) {
    throw new ApiError("invalid-argument", "Thiếu orderId/lý do.");
  }
  const orderSnap = await db.doc(`orders/${orderId}`).get();
  if (!orderSnap.exists) {
    throw new ApiError("not-found", "Không tìm thấy đơn hàng.");
  }
  const order = orderSnap.data() as FirebaseFirestore.DocumentData;
  if (order.buyerId !== ctx.uid) {
    throw new ApiError("permission-denied", "Đơn này không thuộc về bạn.");
  }
  if (order.status !== "COMPLETED") {
    throw new ApiError(
      "failed-precondition",
      "Chỉ khiếu nại đơn đã nhận hàng.",
    );
  }
  const ref = await db.collection("complaints").add({
    orderId,
    buyerId: ctx.uid,
    storeId: order.storeId,
    dealTitle: order.dealTitle ?? "",
    reason,
    note,
    status: "open",
    createdAt: FieldValue.serverTimestamp(),
  });
  await notifyUser(order.storeId as string, {
    type: "complaint",
    title: "Có khiếu nại mới",
    body: `Đơn ${order.dealTitle ?? ""}: ${reason}`,
  });
  return { ok: true, complaintId: ref.id };
}

/// Xử lý khiếu nại (quán của đơn đó, hoặc admin).
export async function resolveComplaint(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;
  const complaintId =
    typeof d.complaintId === "string" ? d.complaintId.trim() : "";
  const resolution =
    typeof d.resolution === "string" ? d.resolution.trim() : "";
  if (!complaintId || !resolution) {
    throw new ApiError("invalid-argument", "Thiếu complaintId/cách xử lý.");
  }
  const ref = db.doc(`complaints/${complaintId}`);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new ApiError("not-found", "Không tìm thấy khiếu nại.");
  }
  const c = snap.data() as FirebaseFirestore.DocumentData;
  const isAdmin = ctx.token.admin === true;
  if (!isAdmin && c.storeId !== ctx.uid) {
    throw new ApiError(
      "permission-denied",
      "Khiếu nại này không thuộc cửa hàng của bạn.",
    );
  }
  if (c.status !== "open") {
    throw new ApiError("failed-precondition", "Khiếu nại này đã được xử lý.");
  }
  await ref.update({
    status: "resolved",
    resolution,
    resolvedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await notifyUser(c.buyerId as string, {
    type: "complaint_resolved",
    title: "Khiếu nại đã được xử lý",
    body: resolution,
  });
  return { ok: true };
}

/// Gửi yêu cầu hỗ trợ (CSKH, mọi vai trò).
export async function createSupportTicket(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;
  const title = typeof d.title === "string" ? d.title.trim() : "";
  const message = typeof d.message === "string" ? d.message.trim() : "";
  if (!title || !message) {
    throw new ApiError("invalid-argument", "Thiếu tiêu đề/nội dung.");
  }
  const ref = await db.collection("supportTickets").add({
    userId: ctx.uid,
    title,
    message,
    status: "open",
    adminReply: null,
    createdAt: FieldValue.serverTimestamp(),
  });
  return { ok: true, ticketId: ref.id };
}

/// Trả lời + đóng yêu cầu hỗ trợ (admin).
export async function replySupportTicket(ctx: AuthContext, data: unknown) {
  const db = getDb();
  const d = (data ?? {}) as Record<string, unknown>;
  const ticketId = typeof d.ticketId === "string" ? d.ticketId.trim() : "";
  const reply = typeof d.reply === "string" ? d.reply.trim() : "";
  if (!ticketId || !reply) {
    throw new ApiError(
      "invalid-argument",
      "Thiếu ticketId/nội dung trả lời.",
    );
  }
  const ref = db.doc(`supportTickets/${ticketId}`);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new ApiError("not-found", "Không tìm thấy yêu cầu hỗ trợ.");
  }
  const t = snap.data() as FirebaseFirestore.DocumentData;
  await ref.update({
    adminReply: reply,
    status: "closed",
    updatedAt: FieldValue.serverTimestamp(),
  });
  await notifyUser(t.userId as string, {
    type: "support_reply",
    title: "Hỗ trợ đã trả lời",
    body: reply,
  });
  return { ok: true };
}
