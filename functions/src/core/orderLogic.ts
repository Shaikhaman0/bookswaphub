// Server-side price and eligibility rules for buying a book.
// The Flutter app NEVER sends a price. We read the price from the book document.

export interface BookForSale {
  ownerId: string;
  status: string;
  listingType: string; // 'swap' | 'sale' | 'both'
  price?: number | null;
  currency?: string | null;
  title?: string;
  /** Checkout hold: someone else is currently paying for this book. */
  pendingOrderId?: string | null;
  pendingOrderExpiresAtMs?: number | null;
  pendingBuyerId?: string | null;
}

export const MAX_PRICE_MAJOR_UNITS = 100000; // sanity cap, test mode

export type OrderCheck =
  | { ok: true; amountMinor: number; currency: string }
  | { ok: false; code: 'permission-denied' | 'not-found' | 'failed-precondition' | 'invalid-argument'; message: string };

export function computeOrder(
  buyerUid: string,
  book: BookForSale | null,
  defaultCurrency: string,
  nowMs: number = Date.now(),
): OrderCheck {
  if (!buyerUid) return { ok: false, code: 'permission-denied', message: 'You must be signed in.' };
  if (!book) return { ok: false, code: 'not-found', message: 'That book does not exist.' };
  if (book.ownerId === buyerUid) {
    return { ok: false, code: 'failed-precondition', message: 'You cannot buy your own book.' };
  }
  if (book.status !== 'available') {
    return { ok: false, code: 'failed-precondition', message: 'This book is not available.' };
  }
  if (book.listingType !== 'sale' && book.listingType !== 'both') {
    return { ok: false, code: 'failed-precondition', message: 'This book is not listed for sale.' };
  }
  if (
    book.pendingOrderId &&
    book.pendingBuyerId !== buyerUid &&
    typeof book.pendingOrderExpiresAtMs === 'number' &&
    book.pendingOrderExpiresAtMs > nowMs
  ) {
    return {
      ok: false,
      code: 'failed-precondition',
      message: 'Someone else is checking out this book right now. Try again in a few minutes.',
    };
  }
  const price = book.price;
  if (typeof price !== 'number' || !Number.isFinite(price) || price <= 0) {
    return { ok: false, code: 'invalid-argument', message: 'This book has no valid price.' };
  }
  if (price > MAX_PRICE_MAJOR_UNITS) {
    return { ok: false, code: 'invalid-argument', message: 'Price is above the allowed test limit.' };
  }
  const minor = Math.round(price * 100);
  if (Math.abs(minor / 100 - price) > 1e-9) {
    return { ok: false, code: 'invalid-argument', message: 'Price has too many decimal places.' };
  }
  const currency = (book.currency ?? defaultCurrency).toLowerCase();
  if (currency !== defaultCurrency.toLowerCase()) {
    return { ok: false, code: 'invalid-argument', message: 'Unsupported currency for this book.' };
  }
  return { ok: true, amountMinor: minor, currency };
}
