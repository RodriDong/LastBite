import { createEndpoint } from "./http";
import * as handlers from "./handlers";

/**
 * Bảng route POST dùng chung cho server local (src/local.ts) và Vercel
 * (api/[endpoint].ts). Thêm endpoint mới thì thêm 1 dòng ở đây là đủ cả 2.
 *
 * Lý do phải có bảng này: gói Vercel Hobby giới hạn 12 function/deployment,
 * mà mỗi file trong api/ là 1 function. Gộp về 1 file router duy nhất thì
 * không bao giờ chạm trần nữa, URL phía app giữ nguyên (/api/<tên>).
 */
export const ROUTES: Record<string, ReturnType<typeof createEndpoint>> = {
  "/api/bootstrap": createEndpoint("auth", handlers.bootstrap),
  "/api/becomeSeller": createEndpoint("auth", handlers.becomeSeller),
  "/api/grantSellerRole": createEndpoint("admin", handlers.grantSellerRole),
  "/api/createDeal": createEndpoint("seller", handlers.createDeal),
  "/api/pauseDeal": createEndpoint("seller", handlers.pauseDeal),
  "/api/createOrder": createEndpoint("auth", handlers.createOrder),
  "/api/cancelOrder": createEndpoint("auth", handlers.cancelOrder),
  "/api/confirmPickup": createEndpoint("seller", handlers.confirmPickup),
  "/api/updateStoreProfile": createEndpoint("seller", handlers.updateStoreProfile),
  "/api/submitReview": createEndpoint("auth", handlers.submitReview),
  "/api/submitCertificate": createEndpoint("seller", handlers.submitCertificate),
  "/api/toggleFavorite": createEndpoint("auth", handlers.toggleFavorite),
  "/api/exchangeVoucher": createEndpoint("auth", handlers.exchangeVoucher),
  "/api/confirmFakePayment": createEndpoint("auth", handlers.confirmFakePayment),
  "/api/renewShopFee": createEndpoint("seller", handlers.renewShopFee),
  "/api/requestPromotion": createEndpoint("seller", handlers.requestPromotion),
  "/api/reviewPromotion": createEndpoint("admin", handlers.reviewPromotion),
  "/api/reportSettlement": createEndpoint("seller", handlers.reportSettlement),
  "/api/confirmSettlement": createEndpoint("admin", handlers.confirmSettlement),
  "/api/reportComplaint": createEndpoint("auth", handlers.reportComplaint),
  "/api/resolveComplaint": createEndpoint("auth", handlers.resolveComplaint),
  "/api/createSupportTicket": createEndpoint("auth", handlers.createSupportTicket),
  "/api/replySupportTicket": createEndpoint("admin", handlers.replySupportTicket),
  "/api/updateBuyerProfile": createEndpoint("auth", handlers.updateBuyerProfile),
  "/api/updateDeal": createEndpoint("seller", handlers.updateDeal),
  "/api/reviewCertificate": createEndpoint("admin", handlers.reviewCertificate),
  "/api/saveFcmToken": createEndpoint("auth", handlers.saveFcmToken),
  "/api/markNotificationsRead": createEndpoint("auth", handlers.markNotificationsRead),
};
