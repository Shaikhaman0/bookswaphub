// Decides what a verified Stripe event does to an order.
// Storage is injected (Store/Tx) so the logic is testable without Firebase.
// In production, index.ts implements Store with a Firestore transaction.

export interface StripeEvent {
  id: string;
  type: string;
  livemode: boolean;
  data: {
    object: {
      id: string;
      amount?: number;
      currency?: string;
      metadata?: Record<string, string>;
      last_payment_error?: { message?: string };
    };
  };
}

export type OrderStatus = 'pending' | 'paid' | 'failed' | 'cancelled' | 'amount_mismatch';

export interface OrderDoc {
  id: string;
  buyerId: string;
  sellerId: string;
  bookId: string;
  amountMinor: number;
  currency: string;
  status: OrderStatus;
  paymentIntentId: string;
}

export interface Tx {
  eventAlreadyProcessed(eventId: string): Promise<boolean>;
  getOrder(orderId: string): Promise<OrderDoc | null>;
  getBook(bookId: string): Promise<{ status: string; pendingOrderId?: string | null } | null>;
  recordEvent(eventId: string, type: string, outcome: string): void;
  updateOrder(orderId: string, patch: Record<string, unknown>): void;
  markBookSold(bookId: string, buyerId: string): void;
  clearBookHold(bookId: string, orderId: string): void;
  recordPayment(paymentIntentId: string, data: Record<string, unknown>): void;
  notify(uid: string, payload: { type: string; title: string; body: string; actionRoute: string }): void;
}

export interface Store {
  runTransaction<T>(fn: (tx: Tx) => Promise<T>): Promise<T>;
}

export type ProcessOutcome =
  | 'duplicate'
  | 'paid'
  | 'failed'
  | 'cancelled'
  | 'ignored'
  | 'amount_mismatch'
  | 'live_event_rejected'
  | 'retry_later';

const HANDLED = new Set([
  'payment_intent.succeeded',
  'payment_intent.payment_failed',
  'payment_intent.canceled',
]);

export async function processStripeEvent(event: StripeEvent, store: Store): Promise<ProcessOutcome> {
  // Defense in depth: this app is TEST ONLY.
  if (event.livemode === true) return 'live_event_rejected';

  if (!HANDLED.has(event.type)) {
    // Not an error: Stripe may send many event types. We just acknowledge.
    return 'ignored';
  }

  return store.runTransaction(async (tx) => {
    if (await tx.eventAlreadyProcessed(event.id)) return 'duplicate' as ProcessOutcome;

    const pi = event.data.object;
    const orderId = pi.metadata?.orderId;
    if (!orderId) {
      tx.recordEvent(event.id, event.type, 'ignored_no_order');
      return 'ignored' as ProcessOutcome;
    }
    const order = await tx.getOrder(orderId);
    // Race: Stripe's event can arrive before we saved the PaymentIntent id on the order.
    // Do NOT record the event; answer "retry later" so Stripe delivers it again.
    if (order && !order.paymentIntentId) return 'retry_later' as ProcessOutcome;
    // The PaymentIntent id must match what WE stored. This stops forged metadata.
    if (!order || order.paymentIntentId !== pi.id) {
      tx.recordEvent(event.id, event.type, 'ignored_unknown_order');
      return 'ignored' as ProcessOutcome;
    }

    if (event.type === 'payment_intent.succeeded') {
      if (order.status === 'paid') {
        tx.recordEvent(event.id, event.type, 'ignored_already_paid');
        return 'ignored' as ProcessOutcome;
      }
      if (order.status === 'cancelled' || order.status === 'amount_mismatch') {
        tx.recordEvent(event.id, event.type, `ignored_order_${order.status}`);
        return 'ignored' as ProcessOutcome;
      }
      const currency = (pi.currency ?? '').toLowerCase();
      if (pi.amount !== order.amountMinor || currency !== order.currency.toLowerCase()) {
        tx.updateOrder(orderId, { status: 'amount_mismatch', reviewNote: 'amount_or_currency_mismatch' });
        tx.recordEvent(event.id, event.type, 'amount_mismatch');
        return 'amount_mismatch' as ProcessOutcome;
      }
      const book = await tx.getBook(order.bookId);
      const patch: Record<string, unknown> = { status: 'paid' };
      if (!book || book.status !== 'available') patch.reviewNote = 'book_not_available_at_payment';
      tx.updateOrder(orderId, patch);
      tx.markBookSold(order.bookId, order.buyerId);
      tx.recordPayment(pi.id, {
        orderId,
        buyerId: order.buyerId,
        sellerId: order.sellerId,
        amountMinor: order.amountMinor,
        currency: order.currency,
        status: 'succeeded',
        testMode: true,
      });
      tx.notify(order.sellerId, {
        type: 'system',
        title: 'Your book was purchased (test payment)',
        body: 'A buyer completed a Stripe TEST payment for your book.',
        actionRoute: '/my-books',
      });
      tx.notify(order.buyerId, {
        type: 'system',
        title: 'Payment confirmed (test mode)',
        body: 'Your Stripe TEST payment was verified by the server.',
        actionRoute: `/book/${order.bookId}`,
      });
      tx.recordEvent(event.id, event.type, 'paid');
      return 'paid' as ProcessOutcome;
    }

    if (event.type === 'payment_intent.payment_failed') {
      if (order.status !== 'pending') {
        tx.recordEvent(event.id, event.type, `ignored_order_${order.status}`);
        return 'ignored' as ProcessOutcome;
      }
      tx.updateOrder(orderId, {
        status: 'failed',
        failureMessage: (pi.last_payment_error?.message ?? 'Payment failed').slice(0, 300),
      });
      const heldBook = await tx.getBook(order.bookId);
      if (heldBook?.pendingOrderId === orderId) tx.clearBookHold(order.bookId, orderId);
      tx.recordEvent(event.id, event.type, 'failed');
      return 'failed' as ProcessOutcome;
    }

    // payment_intent.canceled
    if (order.status === 'paid') {
      tx.recordEvent(event.id, event.type, 'ignored_already_paid');
      return 'ignored' as ProcessOutcome;
    }
    tx.updateOrder(orderId, { status: 'cancelled' });
    const heldBook = await tx.getBook(order.bookId);
    if (heldBook?.pendingOrderId === orderId) tx.clearBookHold(order.bookId, orderId);
    tx.recordEvent(event.id, event.type, 'cancelled');
    return 'cancelled' as ProcessOutcome;
  });
}
