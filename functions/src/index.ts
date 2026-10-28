import { setGlobalOptions } from 'firebase-functions/v2';

// Keep this in sync with the region used by the Flutter app (FirebaseFunctions.instance default = us-central1).
setGlobalOptions({ region: 'us-central1', maxInstances: 10 });

export { createSwapRequest, updateSwapStatus } from './swaps';
export { createOrder, stripeWebhook } from './orders';
export { aiAssistant } from './ai';
export { onMessageCreated } from './chat';
export { submitReview } from './reviews';
export {
  adminStats,
  adminUpdateReport,
  adminModerateBook,
  adminSetUserDisabled,
  adminBroadcast,
  adminManageSwap,
  adminDeleteUser,
} from './admin';
export { deleteMyAccount } from './account';
