# LastBite — Firestore Schema

Phiên bản: v0.1 (bản nháp cho Emulator, sẽ chốt ở Phase 5).
Quy ước chung cho mọi collection:

- Thời gian: **Timestamp (UTC)**. Tên field thời gian kết thúc bằng `At`
  (`createdAt`, `saleEndAt`, `completedAt`...). Báo cáo/format theo **Asia/Ho_Chi_Minh**
  ở tầng hiển thị, không lưu giờ local vào DB.
- Tiền: **số nguyên VNĐ** (`int`). Không dùng float cho tiền.
- Giá hiển thị cho khách = `max(round(originalPrice * (1 - discount)), minPrice)`,
  làm tròn đến nghìn đồng. Logic discount chuẩn nằm ở `functions/src/pricing.ts`.
- `id` document: auto-ID của Firestore, trừ `users/{uid}` dùng Auth UID.

---

## 1. `users/{uid}`

Hồ sơ người dùng. Tạo bởi Auth trigger `onUserCreate`.

| Field | Kiểu | Ghi chú |
|---|---|---|
| `email` | string | Email đăng nhập |
| `displayName` | string | Tên hiển thị |
| `phone` | string? | Tùy chọn |
| `greenPoints` | int | Điểm xanh (mặc định 0) |
| `rescuedMeals` | int | Số bữa ăn đã cứu (mặc định 0) |
| `savedMoney` | int | Tổng tiền đã tiết kiệm, VNĐ (mặc định 0) |
| `createdAt` | Timestamp | |
| `updatedAt` | Timestamp | |
| `fcmToken` | string? | Token FCM Android (bản Hoàn thiện) — để server gửi push |
| `fcmPlatform` | string? | `android` (web bỏ qua) |
| `fcmUpdatedAt` | Timestamp | |

Quyền seller **không** lưu ở đây làm nguồn chân lý — dùng custom claim
`seller: true` trên Auth token. (Có thể mirror `isSeller` để query cho tiện, nhưng
Rules/Functions luôn kiểm tra claim.)

## 2. `stores/{storeId}`

Cửa hàng. `ownerUid` là UID của seller sở hữu.

| Field | Kiểu | Ghi chú |
|---|---|---|
| `ownerUid` | string | UID của seller |
| `name` | string | Tên cửa hàng |
| `address` | string | Địa chỉ |
| `location` | GeoPoint | Tọa độ để hiển thị bản đồ |
| `phone` | string? | |
| `rating` | number | Điểm đánh giá trung bình |
| `ratingCount` | int | Số lượt đánh giá |
| `isApproved` | bool | Cửa hàng đã được duyệt |
| `openHours` | string? | VD: "07:00 – 22:00" |
| `certStatus` | string | Phase 7 — ATTP: `none`/`pending`/`approved`/`rejected` (mặc định `none` khi vắng mặt) |
| `certUrl` | string? | Phase 7 — URL ảnh giấy chứng nhận trên Vercel Blob (công khai theo link) |
| `certSubmittedAt` / `certReviewedAt` | Timestamp? | Phase 7 — mốc nộp / duyệt chứng nhận |
| `certReviewNote` | string? | Phase 7 — ghi chú khi từ chối (admin ghi trong Console) |
| `createdAt` / `updatedAt` | Timestamp | |

### 2.1. `stores/{storeId}/dailyStats/{yyyyMMdd}`

Tổng hợp doanh thu theo ngày (múi giờ Asia/Ho_Chi_Minh, key `yyyyMMdd`), do function
`confirmPickup` cập nhật trong transaction.

| Field | Kiểu | Ghi chú |
|---|---|---|
| `revenue` | int | Tổng tiền đơn hoàn tất trong ngày, VNĐ |
| `orders` | int | Số đơn hoàn tất |
| `commission` | int | Tổng hoa hồng 10%, VNĐ |
| `rescuedMeals` | int | Số phần ăn đã cứu |

## 3. `deals/{dealId}` — "SurpriseBox"

Một deal giảm giá theo giờ của một cửa hàng.

| Field | Kiểu | Ghi chú |
|---|---|---|
| `storeId` | string | Tham chiếu `stores/{storeId}` |
| `storeName` | string | Denormalize để hiển thị nhanh |
| `storeAddress` | string | Denormalize từ `stores/{id}.address` — hiển thị nhanh (thêm ở Phase 3) |
| `storeLat` | number? | Denormalize từ `stores/{id}.location.latitude` — ghim bản đồ (thêm ở Phase 3) |
| `storeLng` | number? | Denormalize từ `stores/{id}.location.longitude` — ghim bản đồ (thêm ở Phase 3) |
| `title` | string | Tên deal |
| `description` | string | Mô tả |
| `icon` | string | Emoji/biểu tượng (giữ tương thích UI hiện tại) |
| `category` | string | Chốt cứng (Phase 9): Bánh ngọt, Cơm, Bún phở, Đồ uống, Hoa quả, Rau củ, Pizza, Món chay, Khác — server từ chối ngoài danh sách khi tạo mới |
| `imageUrl` | string? | Phase 8: ảnh thật của deal trên Vercel Blob; null → app hiện emoji |
| `originalPrice` | int | Giá gốc, VNĐ |
| `minPrice` | int | Giá sàn — giá bán không được thấp hơn |
| `maxDiscountPercent` | int | Mặc định 60 (một số deal 50/55/70 như mock hiện tại) |
| `totalQty` | int | Tổng số phần mở bán |
| `remainingQty` | int | Số phần còn lại (chỉ function được trừ) |
| `saleEndAt` | Timestamp | Hết giờ → không cho đặt |
| `pickupWindow` | string | VD: "20:00 – 21:30" |
| `pickupSlots` | string[]? | Các slot cho khách chọn, VD: ["20:00 – 20:30", ...] |
| `status` | string | `active` \| `paused` \| `expired` \| `soldout` |
| `createdAt` / `updatedAt` | Timestamp | |

**Bảng discount theo `remaining = saleEndAt - now`:**

| Thời gian còn lại | Discount |
|---|---|
| > 180 phút | 20% |
| 60 – 180 phút | 40% |
| > 0 – < 60 phút | `maxDiscountPercent` (mặc định 60%) |
| ≤ 0 | hết giờ, không cho đặt |

Client chỉ dùng bảng này để **preview**; `createOrder` tính lại ở server.

## 4. `orders/{orderId}`

Một đơn hàng: **một cửa hàng, một loại deal, một số lượng**.

| Field | Kiểu | Ghi chú |
|---|---|---|
| `dealId` | string | Tham chiếu `deals/{dealId}` |
| `storeId` | string | Tham chiếu `stores/{storeId}` |
| `buyerId` | string | UID người mua |
| `buyerName` | string | Denormalize |
| `dealTitle` | string | Denormalize từ deal (Phase 4) — hiển thị màn Đơn hàng |
| `dealIcon` | string | Denormalize từ deal (Phase 4) |
| `storeName` | string | Denormalize từ deal (Phase 4) |
| `quantity` | int | Số lượng (≥ 1) |
| `unitLockedPrice` | int | Đơn giá đã khóa tại lúc đặt, VNĐ |
| `totalLockedPrice` | int | = `unitLockedPrice * quantity`, VNĐ |
| `originalTotal` | int | = `originalPrice * quantity`, để tính "đã tiết kiệm" |
| `pickupCode` | string | Mã nhận hàng (VD: "A2417"), unique |
| `pickupSlot` | string | Slot khách đã chọn |
| `status` | string | `PENDING` \| `COMPLETED` \| `CANCELLED` |
| `paymentStatus` | string | `UNPAID` → `PAID_ON_PICKUP` khi seller xác nhận |
| `commissionAmount` | int | = `round(totalLockedPrice * 10%)`, ghi khi COMPLETED |
| `saleEndAt` | Timestamp | Denormalize từ deal (Phase 4) — đếm ngược ở màn Đơn hàng |
| `createdAt` | Timestamp | |
| `completedAt` | Timestamp? | |
| `cancelledAt` | Timestamp? | |
| `reviewed` | bool? | Phase 6: `submitReview` ghi `true` sau khi buyer đánh giá |
| `reviewRating` | int? | Phase 6: số sao của đánh giá tương ứng (1–5) |

Không có thanh toán online trong phạm vi demo — `paymentStatus` chỉ chuyển sang
`PAID_ON_PICKUP` cùng lúc đơn `COMPLETED` (xác nhận tại quầy).

## 4.1. `reviews/{orderId}` (Phase 6)

Đánh giá của buyer cho 1 đơn đã hoàn thành. **Doc id = orderId** → mỗi đơn
tối đa 1 đánh giá, chống trùng ở tầng dữ liệu.

| Field | Kiểu | Ghi chú |
|---|---|---|
| `orderId` | string | = doc id |
| `storeId` | string | Quán được đánh giá (query hiển thị theo quán) |
| `dealId` | string | |
| `buyerUid` | string | |
| `buyerName` | string | Denormalize từ order |
| `rating` | int | 1–5 |
| `comment` | string | ≤ 500 ký tự, có thể rỗng |
| `createdAt` | Timestamp | |

Ghi chỉ qua API `submitReview` (nó đồng thời cập nhật trung bình cộng dồn
`stores.rating`/`stores.ratingCount`). Rules: user đã đăng nhập được đọc,
client không được ghi.

## 4.2. `chats/{chatId}` + `messages` (Phase 9)

Chat buyer <-> seller, ghi thẳng từ client (ngoại lệ realtime — xem
ghi chú trong `firestore.rules`). **Doc id = `{buyerUid}__{storeId}`**
→ mỗi cặp buyer–quán đúng 1 thread.

| Field | Kiểu | Ghi chú |
|---|---|---|
| `buyerUid` / `buyerName` | string | Phía khách |
| `storeId` / `storeName` | string | Phía quán (storeId = uid seller) |
| `lastMessage` / `lastAt` | string / Timestamp | Xem trước ở danh sách hội thoại |
| `buyerUnread` / `sellerUnread` | int | Số tin chưa đọc của từng phía |

Subcollection `chats/{chatId}/messages/{autoId}`: `senderUid`,
`senderRole` (`buyer`/`seller`), `text` (1–1000 ký tự), `createdAt`.
Rules: chỉ 2 bên của thread đọc/ghi được; không sửa được buyerUid/
storeId của thread; message không sửa/xóa. Query danh sách lọc theo
`buyerUid`/`storeId` (equality) + sắp xếp lastAt phía client nên
không cần composite index.

### 1.1. `users/{uid}/favorites/{storeId}` (bản Hoàn thiện)

| Field | Kiểu | Ghi chú |
|---|---|---|
| `storeId` | string | = id doc |
| `storeName` | string | Tên quán lúc bấm yêu thích |
| `createdAt` | Timestamp | |

Rules: chỉ chủ tài khoản đọc; ghi qua server (`toggleFavorite`).

### 1.2. `notifications/{notifId}` (bản Hoàn thiện)

| Field | Kiểu | Ghi chú |
|---|---|---|
| `userId` | string | Người nhận |
| `type` | string | `order_new` / `order_cancelled` / `order_completed` / `review_new` / `cert_result` |
| `title` / `body` | string | Nội dung hiển thị |
| `orderId` | string? | Đơn liên quan (để mở chi tiết đơn) |
| `read` | bool | Đã đọc hay chưa |
| `createdAt` | Timestamp | |

Rules: chỉ người nhận đọc; ghi/đánh dấu qua server.

## 5. Indexes (xem `firestore.indexes.json`)

Composite indexes dự kiến:

1. `deals`: `status` ASC + `saleEndAt` ASC — query deal đang bán còn hạn.
2. `deals`: `storeId` ASC + `status` ASC + `saleEndAt` DESC — deal của một cửa hàng (seller).
3. `orders`: `buyerId` ASC + `status` ASC + `createdAt` DESC — đơn của người mua theo trạng thái.
4. `orders`: `storeId` ASC + `status` ASC + `createdAt` DESC — đơn của cửa hàng theo trạng thái.
5. `orders`: `pickupCode` ASC — tra cứu mã QR (single-field, có sẵn).
6. `notifications`: `userId` ASC + `createdAt` DESC — trung tâm thông báo (bản Hoàn thiện).

## 6. Ví dụ document

```jsonc
// deals/abc123
{
  "storeId": "store_luami",
  "storeName": "Tiệm Lúa Mì",
  "title": "Combo bánh ngọt cuối ngày",
  "description": "Bánh còn mới, nướng trong ngày...",
  "icon": "🥐",
  "category": "Bánh ngọt",
  "originalPrice": 80000,
  "minPrice": 24000,
  "maxDiscountPercent": 60,
  "totalQty": 10,
  "remainingQty": 4,
  "saleEndAt": { "Timestamp": "2026-10-19T14:30:00Z" },
  "pickupWindow": "20:00 – 21:30",
  "pickupSlots": ["20:00 – 20:30", "20:30 – 21:00", "21:00 – 21:30"],
  "status": "active"
}
```

```jsonc
// orders/xyz789
{
  "dealId": "abc123",
  "storeId": "store_luami",
  "buyerId": "uid_buyer_1",
  "buyerName": "Nguyễn Minh",
  "quantity": 1,
  "unitLockedPrice": 32000,
  "totalLockedPrice": 32000,
  "originalTotal": 80000,
  "pickupCode": "A2417",
  "pickupSlot": "20:30 – 21:00",
  "status": "PENDING",
  "paymentStatus": "UNPAID",
  "commissionAmount": 0
}
```
