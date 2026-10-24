/**
 * Trung tâm thông báo + push (bản Hoàn thiện 24/10/2026).
 *
 * Mỗi sự kiện quan trọng của đơn hàng ghi 1 doc vào `notifications`
 * (người nhận đọc trong app) và — nếu tài khoản có FCM token — gửi
 * thêm push Android. Mọi lỗi ở đây đều được nuốt: thông báo không bao
 * giờ được phép làm hỏng luồng chính (đặt/hủy/xác nhận đơn).
 */
import { FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { db as getDb } from "./admin";

export interface NotifyInput {
  type: string;
  title: string;
  body: string;
  orderId?: string;
}

export async function notifyUser(
  userId: string,
  input: NotifyInput,
): Promise<void> {
  if (!userId) return;
  try {
    const db = getDb();
    await db.collection("notifications").add({
      userId,
      type: input.type,
      title: input.title,
      body: input.body,
      orderId: input.orderId ?? null,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
    await sendPush(userId, input.title, input.body, input.orderId);
  } catch {
    // Thông báo là phụ — không làm hỏng luồng chính.
  }
}

async function sendPush(
  userId: string,
  title: string,
  body: string,
  orderId?: string,
): Promise<void> {
  try {
    const db = getDb();
    const snap = await db.doc(`users/${userId}`).get();
    const token = snap.data()?.fcmToken;
    if (typeof token !== "string" || token.length === 0) return;
    await getMessaging().send({
      token,
      notification: { title, body },
      data: orderId ? { orderId } : {},
    });
  } catch {
    // Token hết hạn/bị thu hồi: lần mở app sau client tự cập nhật lại.
  }
}
