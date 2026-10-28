// Stripe TEST-MODE checkout. See docs/STRIPE_TEST_MODE.md.
import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { db, FieldValue, requireVerified, str } from './shared';
import { assertStripeTestMode, StripeConfigError, type StripeTestConfig } from './core/stripeMode';
import { computeOrder } from './core/orderLogic';
import { createPaymentIntent, StripeApiError } from './core/stripeClient';
import { verifyStripeSignature, WebhookSignatureError } from './core/webhookSignature';
import { processStripeEvent, type Store, type Tx, type StripeEvent, type OrderDoc } from './core/webhookProcessor';

const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');
const STRIPE_WEBHOOK_SECRET = defineSecret('STRIPE_WEBHOOK_SECRET');
const HOLD_MS = 15 * 60 * 1000;

function loadConfig(needWebhookSecret: boolean): StripeTestConfig {
  try {
    return assertStripeTestMode(
      {
        STRIPE_MODE: process.env.STRIPE_MODE,
        STRIPE_SECRET_KEY: STRIPE_SECRET_KEY.value(),
        STRIPE_WEBHOOK_SECRET: needWebhookSecret ? STRIPE_WEBHOOK_SECRET.value() : undefined,
        STRIPE_CURRENCY: process.env.STRIPE_CURRENCY,
      },
      { needWebhookSecret },
    );
  } catch (e) {
    if (e instanceof StripeConfigError) {
      console.error(`Stripe configuration error [${e.code}]: ${e.message}`);
      throw new HttpsError('failed-precondition', `Payments are disabled: ${e.message}`);
    }
    throw e;
  }
}

/** Step 2-4 of the flow: validate on the server, create a TEST PaymentIntent, return its client secret. */
export const createOrder = onCall({ secrets: [STRIPE_SECRET_KEY] }, async (request) => {
  const uid = requireVerified(request);
  const bookId = str(request.data?.bookId, 'bookId', 128);
  // NOTE: the client sends NO price. Anything else the client sends is ignored.
  const cfg = loadConfig(false);

  const orderRef = db.collection('orders').doc();
  const prepared = await db.runTransaction(async (tx) => {
    const bookRef = db.doc(`books/${bookId}`);
    const snap = await tx.get(bookRef);
    const book = snap.exists ? snap.data()! : null;
    let pendingBuyerId = book?.pendingBuyerId ?? null;
    if (!pendingBuyerId && book?.pendingOrderId) {
      const pendingOrderSnap = await tx.get(db.doc(`orders/${book.pendingOrderId}`));
      if (pendingOrderSnap.exists) {
        pendingBuyerId = pendingOrderSnap.data()?.buyerId ?? null;
      }
    }
    const check = computeOrder(
      uid,
      book && {
        ownerId: String(book.ownerId),
        status: String(book.status),
        listingType: String(book.listingType),
        price: typeof book.price === 'number' ? book.price : null,
        currency: book.currency ?? null,
        pendingOrderId: book.pendingOrderId ?? null,
        pendingOrderExpiresAtMs: book.pendingOrderExpiresAt?.toMillis?.() ?? null,
        pendingBuyerId,
      },
      cfg.currency,
    );
    if (!check.ok) throw new HttpsError(check.code, check.message);

    tx.update(bookRef, {
      pendingOrderId: orderRef.id,
      pendingOrderExpiresAt: new Date(Date.now() + HOLD_MS),
      pendingBuyerId: uid,
    });
    tx.set(orderRef, {
      buyerId: uid,
      sellerId: String(book!.ownerId),
      bookId,
      bookTitle: String(book!.title ?? ''),
      amountMinor: check.amountMinor,
      currency: check.currency,
      status: 'pending',
      paymentIntentId: '',
      testMode: true,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return check;
  });

  try {
    const pi = await createPaymentIntent(
      cfg,
      {
        amountMinor: prepared.amountMinor,
        currency: prepared.currency,
        metadata: { orderId: orderRef.id, bookId, buyerId: uid, app: 'bookswaphub-test' },
        idempotencyKey: `order-${orderRef.id}`,
      },
      (url, init) => fetch(url, init),
    );
    await orderRef.update({ paymentIntentId: pi.id, updatedAt: FieldValue.serverTimestamp() });
    return {
      orderId: orderRef.id,
      clientSecret: pi.clientSecret,
      amountMinor: prepared.amountMinor,
      currency: prepared.currency,
      testMode: true,
    };
  } catch (e) {
    // Release the checkout hold so the book is not stuck.
    await db.runTransaction(async (tx) => {
      tx.update(orderRef, { status: 'failed', failureMessage: 'Could not start payment', updatedAt: FieldValue.serverTimestamp() });
      tx.update(db.doc(`books/${bookId}`), {
        pendingOrderId: FieldValue.delete(),
        pendingOrderExpiresAt: FieldValue.delete(),
        pendingBuyerId: FieldValue.delete(),
      });
    });
    if (e instanceof StripeConfigError) throw new HttpsError('failed-precondition', e.message);
    if (e instanceof StripeApiError) throw new HttpsError('unavailable', 'The payment service rejected the request.');
    throw new HttpsError('unavailable', 'Could not reach the payment service.');
  }
});

/** Firestore-backed Store used by the (tested) webhook processor. */
function firestoreStore(): Store {
  return {
    runTransaction: (fn) =>
      db.runTransaction(async (t) => {
        const writes: Array<() => void> = [];
        const tx: Tx = {
          async eventAlreadyProcessed(id) {
            return (await t.get(db.doc(`stripeEvents/${id}`))).exists;
          },
          async getOrder(id) {
            const s = await t.get(db.doc(`orders/${id}`));
            return s.exists ? ({ id, ...s.data() } as OrderDoc) : null;
          },
          async getBook(id) {
            const s = await t.get(db.doc(`books/${id}`));
            return s.exists ? { status: String(s.data()!.status), pendingOrderId: s.data()!.pendingOrderId ?? null } : null;
          },
          recordEvent(id, type, outcome) {
            writes.push(() => t.set(db.doc(`stripeEvents/${id}`), { type, outcome, processedAt: FieldValue.serverTimestamp() }));
          },
          updateOrder(id, patch) {
            writes.push(() => t.update(db.doc(`orders/${id}`), { ...patch, updatedAt: FieldValue.serverTimestamp() }));
          },
          markBookSold(bookId, buyerId) {
            writes.push(() =>
              t.update(db.doc(`books/${bookId}`), {
                status: 'sold', soldTo: buyerId,
                pendingOrderId: FieldValue.delete(), pendingOrderExpiresAt: FieldValue.delete(),
                pendingBuyerId: FieldValue.delete(),
                updatedAt: FieldValue.serverTimestamp(),
              }),
            );
          },
          clearBookHold(bookId) {
            writes.push(() => t.update(db.doc(`books/${bookId}`), {
              pendingOrderId: FieldValue.delete(),
              pendingOrderExpiresAt: FieldValue.delete(),
              pendingBuyerId: FieldValue.delete(),
            }));
          },
          recordPayment(piId, data) {
            writes.push(() => t.set(db.doc(`payments/${piId}`), { ...data, createdAt: FieldValue.serverTimestamp() }));
          },
          notify(uid, p) {
            writes.push(() =>
              t.set(db.collection('notifications').doc(), { userId: uid, ...p, isRead: false, createdAt: FieldValue.serverTimestamp() }),
            );
          },
        };
        const result = await fn(tx);
        writes.forEach((w) => w());
        return result;
      }),
  };
}

/** Steps 7-10: Stripe -> webhook -> signature check -> idempotent processing -> Firestore. */
export const stripeWebhook = onRequest({ secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] }, async (req, res) => {
  if (req.method !== 'POST') { res.status(405).send('Method not allowed'); return; }
  let cfg: StripeTestConfig;
  try {
    cfg = assertStripeTestMode(
      {
        STRIPE_MODE: process.env.STRIPE_MODE,
        STRIPE_SECRET_KEY: STRIPE_SECRET_KEY.value(),
        STRIPE_WEBHOOK_SECRET: STRIPE_WEBHOOK_SECRET.value(),
        STRIPE_CURRENCY: process.env.STRIPE_CURRENCY,
      },
      { needWebhookSecret: true },
    );
  } catch (e) {
    console.error('Stripe config error', e);
    res.status(500).send('Payments are not configured for test mode.');
    return;
  }
  try {
    verifyStripeSignature(req.rawBody, req.header('stripe-signature'), cfg.webhookSecret);
  } catch (e) {
    if (e instanceof WebhookSignatureError) { res.status(400).send('Invalid signature'); return; }
    throw e;
  }
  const event = JSON.parse(req.rawBody.toString('utf8')) as StripeEvent;
  const outcome = await processStripeEvent(event, firestoreStore());
  if (outcome === 'live_event_rejected') { res.status(400).send('Live events are rejected.'); return; }
  if (outcome === 'retry_later') { res.status(409).send('Order not ready, retry'); return; }
  res.status(200).json({ received: true, outcome });
});
