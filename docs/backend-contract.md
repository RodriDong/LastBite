# LastBite — Backend Contract

Hợp đồng kỹ thuật cho Cloud Functions (TypeScript, region `asia-southeast1`) và
Security Rules. Schema dữ liệu: xem `docs/firestore-schema.md`.

Quy ước chung:
- Callable dùng `httpsCallable` từ Flutter (`cloud_functions`).
- Mọi callable yêu cầu đăng nhập, trừ khi ghi rõ.
- Lỗi trả về `HttpsError` với `code` chuẩn (`unauthenticated`, `permission-denied`,
  `not-found`, `failed-precondition`, `invalid-argument`) và `message` tiếng Việt cho client hiển thị.
- Tiền: số nguyên VNĐ. Thời gian: Timestamp.

---

## 1. Logic giá — nguồn chân lý duy nhất

File: `functions/src/pricing.ts` (đã triển khai helper ở bước setup).

```ts
// remainingMs = saleEndAt - now
discountPercent = remainingMs > 180*60_000 ? 20
               : remainingMs >= 60*60_000  ? 40
               : remainingMs > 0           ? deal.maxDiscountPercent // mặc định 60
               : null // hết giờ

unitPrice = max( roundToThousand(originalPrice * (1 - discountPercent/100)), minPrice )
```

- Hết giờ (`remainingMs <= 0`) → không cho đặt (`failed-precondition/SALE_ENDED`).
- Client (Dart) được phép implement công thức tương đương **chỉ để preview**;
  `createOrder` luôn tính lại ở server và dùng giá server.

## 2. Callable Functions

### 2.1. `createOrder`

Người mua đặt deal. Chạy trong **transaction**: kiểm tra deal → tính giá → trừ
`remainingQty` → tạo order.

Request:
```jsonc
{ "dealId": "abc123", "quantity": 1, "pickupSlot": "20:30 – 21:00" }
```

Response:
```jsonc
{
  "orderId": "xyz789",
  "pickupCode": "A2417",
  "unitLockedPrice": 32000,
  "totalLockedPrice": 32000,
  "discountPercent": 60,
  "saleEndAt": "2026-10-19T14:30:00.000Z"
}
```

Lỗi:
| Code | Khi nào |
|---|---|
| `unauthenticated` | Chưa đăng nhập |
| `not-found` | Deal không tồn tại |
| `failed-precondition` | `SALE_ENDED` (hết giờ) · `NOT_ACTIVE` (deal paused/expired/soldout) · `OUT_OF_STOCK` (`remainingQty < quantity`) |
| `invalid-argument` | `quantity < 1`, `pickupSlot` không thuộc deal |

Ghi chú: `pickupCode` sinh ngẫu nhiên, đảm bảo unique (thử lại nếu trùng).

### 2.2. `cancelOrder`

Người mua hủy đơn `PENDING` của chính mình. Transaction hoàn lại `remainingQty`.

Request: `{ "orderId": "xyz789" }` → Response: `{ "ok": true }`

Lỗi: `permission-denied` (không phải chủ đơn), `failed-precondition` (`NOT_PENDING`).

### 2.3. `confirmPickup`

Seller xác nhận giao hàng (quét/nhập `pickupCode`). Trong **transaction**:
`status=COMPLETED`, `paymentStatus=PAID_ON_PICKUP`, `commissionAmount=round(total*10%)`,
`completedAt=now`, cập nhật `stores/{id}/dailyStats/{yyyyMMdd}` (key theo Asia/Ho_Chi_Minh),
cộng `greenPoints`/`rescuedMeals` cho buyer.

Request: `{ "pickupCode": "A2417" }`

Response:
```jsonc
{ "orderId": "xyz789", "totalLockedPrice": 32000, "commissionAmount": 3200 }
```

Lỗi: `permission-denied` (không có claim seller / không phải chủ cửa hàng của đơn),
`not-found` (`CODE_NOT_FOUND`), `failed-precondition` (`NOT_PENDING`).

### 2.4. `createDeal` / `pauseDeal` (seller)

`createDeal` — tạo deal cho cửa hàng của mình. Từ Phase 8/9: nhận thêm
`imageBase64` tùy chọn (ảnh deal → Vercel Blob → `deals.imageUrl`,
kiểm tra JPEG/PNG ≤ ~2,5MB như `submitCertificate`) và `category`
phải thuộc danh sách chốt cứng (xem `DEAL_CATEGORIES` trong
`server/src/deals.ts`, khớp `DealCategories` phía app).

Request:
```jsonc
{
  "storeId": "store_luami",
  "title": "Combo bánh ngọt cuối ngày",
  "description": "...",
  "icon": "🥐",
  "category": "Bánh ngọt",
  "originalPrice": 80000,
  "minPrice": 24000,
  "maxDiscountPercent": 60,
  "totalQty": 10,
  "saleEndAt": "2026-10-19T14:30:00.000Z",
  "pickupWindow": "20:00 – 21:30",
  "pickupSlots": ["20:00 – 20:30", "20:30 – 21:00"]
}
```
Response: `{ "dealId": "abc123" }`. Validate: `saleEndAt > now`, `minPrice <= originalPrice`,
`totalQty >= 1`, `0 < maxDiscountPercent <= 90`.

`pauseDeal` — Request `{ "dealId": "abc123", "paused": true }` → `{ "ok": true }`.

### 2.5. `grantSellerRole` (admin)

Cấp quyền seller: set custom claim `seller: true` + tạo/cập nhật `stores/{storeId}`
(nếu chưa có). Chỉ callable bởi tài khoản có claim `admin`.

Request: `{ "uid": "uid_seller_1", "storeName": "Tiệm Lúa Mì" }` → `{ "ok": true }`

### 2.6. `becomeSeller` (auth — tự đăng ký, Phase 10)

User tự nâng quyền seller cho CHÍNH MÌNH (uid lấy từ token, không
nhận tham số uid): gộp claim cũ + set `seller: true`, tạo
`stores/{uid}` nếu chưa có. App gọi khi đăng ký/đăng nhập với vai
trò "Người bán". Idempotent.

Request: `{ "storeName": "Tiệm Lúa Mì" }` → `{ "ok": true, "created": true }`

### 2.7. Bản Hoàn thiện 24/10/2026 — endpoint mới

| Endpoint | Mode | Mô tả |
|---|---|---|
| `toggleFavorite` | auth | Bật/tắt yêu thích quán (`users/{uid}/favorites/{storeId}`); kiểm tra store tồn tại. |
| `updateBuyerProfile` | auth | Đổi `displayName` (1–60 ký tự) trên users doc. Đổi mật khẩu làm phía client (reauth + updatePassword), không qua server. |
| `updateDeal` | seller | Sửa deal đang bán/tạm dừng: `title` (1–100), `description` (≤500), `category` (trong 9 mục), `imageBase64` (lưu Blob mới). Không sửa giá/số lượng/giờ bán (đã khóa theo đơn chờ). |
| `reviewCertificate` | admin | Duyệt/từ chối chứng nhận ATTP trong app: `certStatus` approved/rejected + `certReviewNote` + `certReviewedAt`; gửi thông báo cho seller. Thay cho sửa tay trong Console. |
| `saveFcmToken` | auth | Lưu FCM token thiết bị (`fcmToken`, `fcmPlatform`) để gửi push Android. |
| `markNotificationsRead` | auth | Đánh dấu đã đọc 1 thông báo (`notificationId`) hoặc tất cả (không truyền id, tối đa 100). |

Thông báo: mỗi sự kiện đơn hàng (mới/hủy/hoàn thành), đánh giá mới, kết quả duyệt chứng nhận đều ghi 1 doc `notifications` cho người nhận + gửi push FCM nếu có token (`server/src/notify.ts`, best-effort — lỗi không làm hỏng luồng chính).

## 3. Triggers & Scheduled

| Function | Loại | Việc làm |
|---|---|---|
| `onUserCreate` | Auth trigger `beforeUserCreated`/`onCreate` | Tạo `users/{uid}` với `greenPoints=0`, `rescuedMeals=0`, `savedMoney=0` |
| `expireDeals` | Scheduled, mỗi 5 phút (`*/5 * * * *`, timezone Asia/Ho_Chi_Minh) | Deal `active` mà `saleEndAt <= now` → `status=expired`. Deal `remainingQty == 0` → `status=soldout` |
| (tương lai) `onOrderCompleted` | Firestore trigger | Gửi thông báo / cập nhật bảng xếp hạng |

## 4. Security Rules — tóm tắt ý định

File: `firestore.rules` — **đã rà soát & siết ở Phase 5 (20/10/2026)** đối chiếu
code client thật: client không ghi Firestore trực tiếp ở bất cứ đâu, nên mọi
`allow write` phía client đều đóng; ghi chỉ qua Cloud Functions (Admin SDK).

- `users/{uid}`: chủ tài khoản (hoặc admin) chỉ **đọc** hồ sơ của mình; tạo/cập nhật
  (kể cả `greenPoints`, `savedMoney`) chỉ do Functions — tránh tự sửa điểm/số liệu.
- `stores/{storeId}`: đọc công khai; tạo bởi `grantSellerRole`, client không ghi.
- `deals/{dealId}`: đọc công khai; **client không được ghi trực tiếp** — mọi tạo/sửa qua function.
- `orders/{orderId}`: đọc khi là chủ đơn hoặc seller của đúng cửa hàng; **client không được
  ghi trực tiếp** — mọi tạo/sửa qua function.
- `stores/{id}/dailyStats/*`: đọc bởi seller chủ cửa hàng; ghi chỉ bởi function.

## 5. Flutter — điểm gọi hàm (Phase 4)

> **Cập nhật 20/10/2026 (tách backend):** các "hàm" dưới đây không còn là
> Cloud Functions. Chúng là endpoint HTTPS của API server riêng trong thư
> mục `server/` (chạy trên Vercel/local), app gọi qua `ApiService` kèm
> Firebase ID token; server xác thực token + custom claims y như callable
> trước đây. Hợp đồng nghiệp vụ (tham số, kết quả, mã lỗi, message tiếng
> Việt) giữ nguyên từng chữ. Riêng `onUserCreate` (Auth trigger) được thay
> bằng endpoint `POST /api/bootstrap` do app gọi sau đăng ký/đăng nhập, và
> `expireDeals` (scheduled) thay bằng quét lười trong `bootstrap`.
> Lý do tách: deploy Cloud Functions bắt buộc gói Blaze — xem
> docs/backend-workflow.md.

| Màn hình hiện tại | Gọi |
|---|---|
| `CheckoutConfirmScreen._confirmBooking` | `createOrder` → nhận `pickupCode`, hiển thị QR (giữ nguyên UI `QrSuccessScreen`) |
| Seller tab Đơn hàng ("Xác nhận" / quét QR) | `confirmPickup` |
| Seller tab Đăng deal | `createDeal` |
| Nút "Tắt deal" (overview) | `pauseDeal` |
| Màn đăng ký (auth_screen) | Auth email/password; nguyện vọng làm seller → luồng duyệt riêng, không tự cấp |
| Seller tab Cửa hàng → "Thông tin cửa hàng" (Phase 6) | `updateStoreProfile` (seller): cập nhật `name`/`address`/`phone`/`openHours` của `stores/{uid}` |
| Buyer sheet đơn COMPLETED → "Đánh giá đơn này" (Phase 6) | `submitReview`: rating 1–5 + comment ≤ 500 ký tự; 1 đơn = 1 đánh giá (`reviews/{orderId}`); cập nhật `stores.rating`/`ratingCount` + `orders.reviewed` trong cùng transaction |
| Màn đăng nhập → "Quên mật khẩu?" (Phase 6) | Không qua server — Firebase Auth `sendPasswordResetEmail` |
| Seller tab Cửa hàng → "Giấy chứng nhận ATTP" (Phase 7) | `submitCertificate` (seller): body `{imageBase64}` (JPEG/PNG thật, ≤ ~2,5MB sau nén phía app); server lưu ảnh lên **Vercel Blob** (Firebase Storage bị khóa sau gói Blaze), đặt `stores.certStatus='pending'` + `certUrl`; admin duyệt trong app (màn Duyệt chứng nhận, endpoint `reviewCertificate`) hoặc sửa tay trong Console |

## 6. Những gì CHƯA chốt (cần user quyết trước Phase 4)

> Cập nhật 20/10/2026: mục 2 đã chốt (giữ format `AXXXX`); mục 4 đã chốt
> (`asia-southeast1` — Firestore của project `last-bite-xyz` tạo ở region này);
> mục 3 áp dụng tạm thời: function nhận quantity 1..99, client hiện gửi 1
> vì UI chưa có bộ chọn số lượng. Còn mở: mục 1.

1. Ai là **admin** đầu tiên để gọi `grantSellerRole`? (Đề xuất: set claim `admin` thủ công
   cho 1 tài khoản qua Firebase CLI/Auth Emulator UI.)
2. `pickupCode` format: giữ `AXXXX` như mock hiện tại? — **Đã chốt: giữ `AXXXX`.**
3. Có cho phép `quantity > 1` ngay từ demo không, hay khóa `quantity = 1` như UI hiện tại?
4. Region deploy sau này: `asia-southeast1` (Singapore, gần VN nhất)? — **Đã chốt.**
