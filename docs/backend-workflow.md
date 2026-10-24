# LastBite — Backend Workflow

Tài liệu kế hoạch backend cho dự án LastBite (app Flutter "giải cứu đồ ăn cuối ngày").
Người phụ trách backend: xem đây là tài liệu điều phối chính.

Trạng thái: **Bước thiết lập (setup)** — cấu hình Firebase/Emulator + khởi tạo Firebase trong
Flutter. Chưa triển khai nghiệp vụ đặt hàng đầy đủ.

Tài liệu liên quan:
- `docs/firestore-schema.md` — cấu trúc dữ liệu Firestore
- `docs/backend-contract.md` — hợp đồng Cloud Functions (callable, trigger, scheduled)

---

## 1. Kiến trúc mục tiêu

```
Flutter (Android + Web)
   │  firebase_auth ──────────────► Firebase Authentication (email/password)
   │  cloud_firestore ────────────► Cloud Firestore (đọc: deals, orders, users)
   │  cloud_functions ────────────► Cloud Functions (callable, TypeScript)
   │                                   ├─ createOrder / cancelOrder
   │                                   ├─ confirmPickup (ghi nhận thanh toán + hoa hồng 10%)
   │                                   ├─ createDeal / pauseDeal (seller)
   │                                   └─ grantSellerRole (admin)
   └──────────────────────────────► Emulator Suite khi dev (auth:9099, firestore:8080,
                                       functions:5001, ui:4000)
```

Nguyên tắc:
- **Client không ghi trực tiếp** vào `deals` và `orders`. Mọi ghi nghiệp vụ đi qua Cloud
  Functions (transaction server-side) để khóa giá, trừ tồn kho, tính hoa hồng.
- **Giá là số nguyên VNĐ**, không bao giờ thấp hơn `minPrice` của deal.
- Mọi thời gian lưu **Timestamp (UTC)**; báo cáo/format theo **Asia/Ho_Chi_Minh** ở tầng hiển thị.
- Không có ví/nạp tiền thật trong phạm vi demo: thanh toán ghi nhận là "thanh toán khi nhận"
  (`paymentStatus = PAID_ON_PICKUP`) tại thời điểm seller xác nhận giao hàng.

## 2. Ánh xạ quy tắc demo → triển khai

| Quy tắc demo | Triển khai |
|---|---|
| Tài khoản thường được mua; quyền seller cấp riêng | Đăng ký mặc định role buyer. Custom claim `seller: true` do admin cấp qua function `grantSellerRole`. Client route màn hình theo claim. |
| Một đơn thuộc một cửa hàng, mua một loại deal với số lượng | `orders/{id}` chứa `storeId`, `dealId`, `quantity`, `unitLockedPrice`, `totalLockedPrice`. |
| Giảm giá theo thời gian còn lại đến `saleEndAt`: >180' → 20%; 60–180' → 40%; 0–60' → 60%; hết giờ không cho đặt | Logic chuẩn nằm trong `functions/src/pricing.ts` (server là nguồn chân lý). Client giữ bản preview tương đương trong Dart để hiển thị, server kiểm tra lại khi `createOrder`. |
| Giá không thấp hơn `minPrice`, tiền là số nguyên VNĐ | `unitPrice = max(round(originalPrice * (1 - discount)), minPrice)`; làm tròn nghìn đồng như hiện tại. |
| Thanh toán khi nhận; hoa hồng 10% khi đơn hoàn tất và đã ghi nhận thanh toán | `confirmPickup` (seller) trong transaction: `status=COMPLETED`, `paymentStatus=PAID_ON_PICKUP`, `commissionAmount = round(totalLockedPrice * 10%)`. |
| Thời gian lưu Timestamp, báo cáo theo Asia/Ho_Chi_Minh | Firestore dùng Timestamp; client format bằng timezone `Asia/Ho_Chi_Minh` (package `timezone` khi cần báo cáo). |

## 3. Điểm tích hợp Firebase trong code Flutter hiện có

| File hiện tại | Vai trò mới |
|---|---|
| `lib/main.dart` | `WidgetsFlutterBinding.ensureInitialized()` → `FirebaseSetup.initialize()` (kết nối Emulator khi debug) rồi mới `runApp`. Không đổi UI. |
| `lib/config/firebase_setup.dart` **(mới)** | Khởi tạo `Firebase.initializeApp()`, trỏ Auth/Firestore/Functions tới Emulator ở chế độ debug. Bọc try/catch để app vẫn chạy mock khi chưa có config. |
| `lib/screens/auth_screen.dart` | `_handleAuth` → `signInWithEmailAndPassword` / `createUserWithEmailAndPassword`. Sau đăng nhập đọc custom claim `seller` để route Buyer/Seller. Nút chọn vai trò ở màn đăng ký chỉ là "đăng ký nguyện vọng", không tự cấp quyền. |
| `lib/models/mock_data.dart` (`AppData`) | Dần thay bằng repository: `DealRepository` (stream deals active), `OrderRepository` (stream orders theo user/store), `UserRepository` (profile/điểm). Getter `currentDiscountPercent`/`currentDynamicPrice` giữ làm **preview**, server kiểm tra lại. |
| `buyer_home_screen.dart` | Tab Trang chủ/Khám phá: `StreamBuilder` query deals (`status==active`, `saleEndAt > now`). Tab Đơn hàng: query orders theo `buyerId`. Tab Ưu đãi/Tôi: đọc `users/{uid}`. |
| `box_detail_screen.dart` (`CheckoutConfirmScreen._confirmBooking`) | Gọi callable `createOrder({dealId, quantity, pickupSlot})`; server trả `orderId`, `pickupCode`, giá đã khóa. Không tự trừ `remainingQty` ở client. |
| `seller_screen.dart` | Đăng deal → callable `createDeal`. Tab Đơn hàng → query orders theo `storeId`. Nút "Xác nhận" / quét QR → callable `confirmPickup({pickupCode})`. Tab Doanh thu → đọc `stores/{id}/dailyStats` do function tổng hợp. |

## 4. Kế hoạch theo giai đoạn

- **Phase 1 — Thiết lập (xong 19/10/2026):** Emulator config, firestore.rules/indexes bản nháp,
  skeleton Functions TS, thêm dependency Firebase vào Flutter, `FirebaseSetup.initialize()`
  trong `main.dart`. Không đụng UI, không deploy.
- **Phase 2 — Auth (code xong 20/10/2026, chưa deploy):**
  - Functions: `onUserCreate` (tạo `users/{uid}`) và `grantSellerRole` (admin cấp claim
    `seller` + tạo `stores/{uid}`) đã triển khai trong `functions/src/index.ts`;
    type-check `tsc --noEmit` pass.
  - Flutter: `lib/services/auth_service.dart` mới; `auth_screen.dart` dùng Auth thật
    (email/password, route theo claim `seller`, tự vào thẳng nếu đã đăng nhập);
    nút Đăng xuất ở buyer/seller gọi `signOut()` thật. Thiết kế UI giữ nguyên.
  - Chưa deploy function, chưa ghi dữ liệu cloud — test bằng Emulator Suite trước.
- **Phase 2 — Auth:** Email/password thật, trigger tạo `users/{uid}`, custom claim seller,
  route theo claim, cập nhật `auth_screen.dart`.
- **Phase 3 — Deals (code xong 20/10/2026, chưa deploy):**
  - Functions: `createDeal` (seller tạo deal cho cửa hàng mình, validate theo
    contract §2.4, denormalize tên/địa chỉ/tọa độ cửa hàng), `pauseDeal`
    (tắt/mở lại deal, chặn deal đã expired/soldout), `expireDeals` (scheduled
    mỗi 5 phút, giờ Asia/Ho_Chi_Minh: hết giờ → expired, hết hàng → soldout).
    Validation tách ra `functions/src/deals.ts`, type-check `tsc` pass,
    18 unit test pass.
  - Flutter: `lib/models/deal.dart` (model Firestore + `toSurpriseBox()`
    cầu nối sang UI), `lib/services/deal_service.dart` (stream deal đang bán /
    deal của cửa hàng + gọi callable); `buyer_home_screen.dart` đọc deal thật
    từ Firestore (có empty state, fallback mock khi chưa cấu hình Firebase);
    `seller_screen.dart` đăng deal qua `createDeal`, nút "Tắt deal" gọi
    `pauseDeal`. Thiết kế UI giữ nguyên. Giá sàn mặc định = 30% giá gốc
    (làm tròn nghìn); khoảng cách hiển thị ước tính từ trung tâm Cầu Giấy.
  - Chưa deploy function, chưa ghi dữ liệu cloud — test bằng Emulator Suite trước.
- **Phase 3 — Deals:** `DealRepository` đọc Firestore; `createDeal`/`pauseDeal`; expire deal
  theo `saleEndAt`; giữ nguyên thiết kế màn hình buyer/seller.
- **Phase 4 — Orders:** `createOrder` (transaction khóa giá + trừ kho), `cancelOrder`,
  `confirmPickup` (thanh toán khi nhận + hoa hồng 10%), QR pickup code.
  **Đã triển khai code 20/10/2026** (chưa deploy): `functions/src/orders.ts`
  (validate + pickupCode + khóa ngày `dailyStats` theo Asia/Ho_Chi_Minh, đã test)
  + 3 handler trong `index.ts`; Flutter: `models/order.dart`,
  `services/order_service.dart`, checkout bỏ ví → thanh toán khi nhận, tab Đơn
  hàng buyer/seller đọc Firestore thật, nút Hủy đơn cho buyer. Chờ test Emulator.
- **Phase 5 — Củng cố:** rà soát Security Rules, indexes cho query thật, báo cáo doanh thu
  theo Asia/Ho_Chi_Minh, kiểm thử trên Emulator trước khi nghĩ tới cloud.
  **Đã làm 20/10/2026:** rules siết theo đúng thực tế client (client không ghi
  trực tiếp nên đóng toàn bộ `allow write` phía client cho `users`/`stores`;
  `deals`/`orders`/`dailyStats` giữ nguyên tắc chỉ-Functions-ghi); 4 composite
  index hiện tại khớp 100% với các query đang chạy — không cần thêm. Tab Doanh
  thu seller + ô "Hôm nay" ở Tổng quan đọc `dailyStats` thật
  (`lib/services/stats_service.dart`). Chưa deploy rules/indexes lên cloud.

## 5. Dev workflow với Emulator Suite

```bash
cd ~/workspace/lastbite          # repo root (chứa firebase.json)
firebase emulators:start          # cần: Firebase CLI + Java 17+ (xem mục 7)
# UI quản trị: http://localhost:4000
```

Flutter ở chế độ debug tự trỏ tới Emulator qua `FirebaseSetup`:
- Auth → `9099`, Firestore → `8080`, Functions → `5001`
- Android emulator dùng host `10.0.2.2`; Web/desktop dùng `localhost`.

Seed dữ liệu demo cho emulator: dùng UI (port 4000) hoặc script import — làm ở Phase 3.

## 6. Ràng buộc an toàn (đã chốt với user)

1. Không deploy, không bật billing, không ghi dữ liệu lên cloud khi chưa được duyệt.
2. Không push code, không sửa tài nguyên bên ngoài khi chưa được duyệt.
3. Không đưa service-account key hay bí mật nào vào app/repository. Cloud Functions dùng
   Application Default Credentials / service account của project khi deploy — không commit key.
4. Project ID thật chưa có: `.firebaserc` đang để `demo-lastbite` **chỉ cho Emulator**.
   Khi có project thật, chạy `firebase use <project-id>` (xem mục 7).

## 7. Việc cần user làm (ngoài phạm vi lượt này)

- [ ] Cài Firebase CLI: `npm i -g firebase-tools`; cài Java 17+ để chạy Emulator Suite.
- [ ] Tạo Firebase project trên console (ghi lại **project ID**), bật:
  - Authentication → Sign-in method → **Email/Password**
  - Firestore Database (chế độ production, region `asia-southeast1` nếu có thể chọn)
- [ ] Trong `lastbite_flutter/`: `dart pub global activate flutterfire_cli` rồi
  `flutterfire configure` → sinh `lib/firebase_options.dart` (file này chứa key công khai,
  an toàn để commit; **không** chứa secret).
- [ ] Sau khi có project ID thật: `cd ~/workspace/lastbite && firebase use <project-id>`.
- [ ] Duyệt `docs/backend-contract.md` trước khi mình triển khai Phase 2–4.

## 6. Tách backend khỏi Cloud Functions (20/10/2026)

**Bối cảnh:** deploy Cloud Functions bắt buộc project ở gói Blaze. Project
`last-bite-xyz` vẫn ở Spark; lần thử nâng Blaze kẹt vì tài khoản thanh toán
tạo bằng thẻ prepaid/debit bị Google yêu cầu ký quỹ 800.000₫. User chốt
hướng **không dùng gói trả phí**: giữ Firebase Spark (Firestore + Auth +
Rules) và chuyển toàn bộ logic functions sang API server riêng.

**Đã làm:**
- Thư mục `server/` (package Node/TypeScript độc lập): port nguyên vẹn
  logic từ `functions/src/index.ts` — validation/pricing dùng lại file cũ,
  chỉ đổi `HttpsError` -> `ApiError` và vỏ callable -> HTTP POST + Bearer
  ID token (server verify bằng Admin SDK). Endpoint: `/api/bootstrap`,
  `/api/grantSellerRole`, `/api/createDeal`, `/api/pauseDeal`,
  `/api/createOrder`, `/api/cancelOrder`, `/api/confirmPickup`,
  `/api/health`.
- Thay thế 2 cơ chế riêng của Functions: Auth trigger `onUserCreate` ->
  endpoint `bootstrap` (app gọi sau đăng ký/đăng nhập); scheduled
  `expireDeals` -> quét lười trong `bootstrap` (tối đa 25 deal/lần).
- App: `ApiService` (package `http`) thay `cloud_functions`;
  `AppConfig.apiBaseUrl` (debug -> localhost:3000/10.0.2.2:3000, release
  -> `productionApiBaseUrl` điền sau khi deploy Vercel). Đọc dữ liệu vẫn
  đi thẳng Firestore; UI/schema/rules không đổi.
- Chạy local: `server` chạy bằng `npm start` sau `npm run build`, trỏ
  Admin SDK vào Emulator Suite qua env `*_EMULATOR_HOST` — không cần
  service-account key khi test local. Trên Vercel: key đặt ở env
  `FIREBASE_SERVICE_ACCOUNT`, không commit.
- Thư mục `functions/` giữ lại làm tham chiếu, không deploy nữa.

## 7. Phase 6 — Quên mật khẩu + hồ sơ cửa hàng + đánh giá (21/10/2026)

- **Quên mật khẩu** (chỉ phía app): nút ở màn đăng nhập ->
  `AuthService.resetPassword` dùng `sendPasswordResetEmail` của Firebase
  Auth. Không cần server.
- **Hồ sơ cửa hàng**: endpoint mới `POST /api/updateStoreProfile` (seller)
  cập nhật `stores/{uid}` (name/address/phone/openHours). App: StoreService
  (đọc stream + gọi API), header Tổng quan + tab Cửa hàng của seller đọc
  tên/rating THẬT từ store doc (bỏ hẳn chữ cứng "Tiệm Lúa Mì" và sao giả
  4,9), form sửa mở từ các mục "Thông tin cửa hàng / Giờ mở cửa / Địa chỉ".
- **Đánh giá**: endpoint `POST /api/submitReview` (buyer, đơn COMPLETED
  của mình, 1 đơn 1 đánh giá ở `reviews/{orderId}`), cập nhật
  `stores.rating`/`ratingCount` cùng transaction. Collection `reviews`
  thêm vào rules (đọc khi đã đăng nhập, ghi chỉ qua server) + composite
  index (storeId, createdAt DESC) — tổng 5 index. App: nút đánh giá trong
  sheet đơn COMPLETED, trang chi tiết deal hiện rating + nhận xét thật
  (bỏ sao giả "4,8 (126 đánh giá)" và câu nhận xét mẫu).
- Deploy kèm theo khi lên cloud: `npx vercel --prod` trong `server/`
  (2 endpoint mới) + `firebase deploy --only firestore` (rules + index).

## 8. Phase 7 — Giấy chứng nhận ATTP cho seller (21/10/2026)

- **Bối cảnh**: Firebase Storage trên project này bị khóa ("To use
  Storage, you need to upgrade your project") và hướng Blaze đã bị loại
  từ 20/10 → ảnh chứng nhận lưu ở **Vercel Blob** (Hobby, miễn phí),
  qua endpoint mới `POST /api/submitCertificate` (seller). Env cần trên
  Vercel: `BLOB_READ_WRITE_TOKEN` (tự sinh khi tạo Blob store và connect
  vào project `server`).
- **Luồng**: seller chọn ảnh trong tab Cửa hàng (image_picker, nén
  maxWidth 1600/q82) -> server kiểm tra chữ ký JPEG/PNG + dung lượng
  ≤ 2,5MB -> upload Blob `certificates/{uid}/...` -> ghi
  `stores.certStatus='pending'`, `certUrl`, `certSubmittedAt`, xóa
  trường duyệt cũ. Admin duyệt TAY trong Firebase Console: mở ảnh qua
  `certUrl`, sửa `certStatus` = `approved`/`rejected` (+ `certReviewNote`
  nếu từ chối, tự thêm `certReviewedAt` nếu muốn).
- **Phía buyer**: trang chi tiết deal hiện huy hiệu "Đã kiểm chứng an
  toàn thực phẩm" khi `certStatus='approved'` (đọc cùng lượt getStore
  với rating của Phase 6 — không thêm query).
- Không đổi rules/index nào (ghi stores vẫn chỉ qua server).

## 9. Phase 8 + 9 — Ảnh deal, danh mục, bản đồ, chat (21/10/2026)

- **Phase 8 (ảnh sản phẩm)**: `createDeal` nhận thêm `imageBase64`
  tùy chọn → upload Vercel Blob thư mục `deals/{uid}/` → ghi
  `deals.imageUrl`. App: form đăng deal có ô chọn ảnh (nén như Phase
  7); thẻ deal + chi tiết hiện ảnh thật, deal không ảnh vẫn hiện emoji.
- **Danh mục chốt cứng**: 9 mục (Bánh ngọt, Cơm, Bún phở, Đồ uống,
  Hoa quả, Rau củ, Pizza, Món chay, Khác) — server (`DEAL_CATEGORIES`)
  từ chối ngoài danh sách khi tạo deal mới; app dùng chung
  `DealCategories` (form seller dạng dropdown, chips lọc buyer có
  thêm Hoa quả/Khác so với bản cũ).
- **Bản đồ (tab Khám phá)**: chip lọc giờ lọc THẬT (≤1 km theo vị trí
  buyer, giảm ≥40%, còn ≤1 giờ; bấm lại chip để bỏ lọc); vị trí thật
  của buyer qua `geolocator` (từ chối quyền thì dùng điểm tham chiếu
  Cầu Giấy như trước) — khoảng cách trên thẻ deal tính lại theo vị
  trí thật; chấm vị trí + nút 🎯 về vị trí của tôi; nút "Chỉ đường"
  mở Google Maps (`url_launcher`) ở thẻ bản đồ và trang chi tiết deal.
- **Chat buyer <-> seller**: collection `chats` (id
  `{buyerUid}__{storeId}`) + subcollection `messages` — NGOẠI LỆ ghi
  thẳng từ client vì cần realtime, rules khóa chỉ 2 bên tham gia
  (xem firestore.rules). Điểm vào: nút "Chat với quán" ở chi tiết
  deal, mục "Tin nhắn" ở tab Tôi (buyer) và tab Cửa hàng (seller);
  có bộ đếm chưa đọc từng phía. Không cần composite index mới
  (lọc equality + sắp xếp phía client).
- Deploy kèm: `npx vercel --prod` (server) + `firebase deploy
  --only firestore` (rules chats; indexes không đổi) + build lại app.

## 10. Phase 10 — Tự đăng ký seller trong app (21/10/2026)

- Bỏ cơ chế cấp seller thủ công (script set-seller / chờ duyệt) cho
  luồng thường: endpoint mới `POST /api/becomeSeller` (auth) — user
  tự nâng quyền cho chính uid của mình (gộp claim cũ, tạo
  `stores/{uid}` nếu chưa có, idempotent).
- App: màn auth vốn đã có chọn vai trò + ô "Tên cửa hàng" — giờ sau
  đăng ký với vai trò Người bán (hoặc đăng nhập chọn vai trò này mà
  chưa có quyền) app gọi `becomeSeller` rồi route theo claim đã
  refresh → vào thẳng giao diện seller. `grantSellerRole` (admin)
  và script set-seller vẫn giữ cho quản trị.
- Đánh đổi đã chấp nhận: ai cũng tự mở quán được; lớp kiểm soát nằm
  ở chứng nhận ATTP (Phase 7) + khả năng thu hồi claim của admin.

## 11. Bản Hoàn thiện 24/10/2026 (một gói duy nhất)

Văn phong toàn app dùng cách nói tích cực ("cuối ngày", "giờ vàng",
"suất ngon", "cứu bữa ngon"); không còn chữ "hết hạn"/"hết giờ" ở giao
diện người dùng. Ví ảo (+100.000đ) và các mục menu chết đã dẹp bỏ, thay
bằng số liệu thật từ users doc.

Thiết kế: bảng màu "cuối ngày ấm áp" (xanh rừng đậm + nền kem + cam
hoàng hôn) trong `AppColors`, thành phần dùng chung ở
`lib/theme/app_theme.dart`, màn chào lần đầu `onboarding_screen.dart`.

Tính năng mới: tìm kiếm (đã có) + sắp xếp (sắp kết thúc / giảm nhiều
nhất / gần nhất), yêu thích quán thật, trung tâm thông báo + push FCM
Android, chi tiết đơn hàng, seller sửa deal + xem đánh giá + biểu đồ
7 ngày, duyệt chứng nhận trong app (claim admin qua
`server/scripts/set-admin.mjs`), buyer sửa tên/mật khẩu, khung giờ
nhận chọn thật từ deal (trước đây checkout gửi cứng '20:30 – 21:00').
