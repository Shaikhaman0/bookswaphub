// Swap workflow rules. Pure functions only (no Firebase) so they can be unit-tested.
// The Cloud Function `updateSwapStatus` calls applySwapAction() inside a Firestore
// transaction, so the client can never choose the next status by itself.

export type SwapStatus =
  | 'pending'
  | 'accepted'
  | 'rejected'
  | 'cancelled'
  | 'inProgress'
  | 'completed';

export type SwapAction = 'accept' | 'reject' | 'cancel' | 'start' | 'confirmComplete';

export const SWAP_ACTIONS: readonly SwapAction[] = [
  'accept',
  'reject',
  'cancel',
  'start',
  'confirmComplete',
];

export interface SwapState {
  status: SwapStatus;
  requesterId: string;
  ownerId: string;
  /** Participants who confirmed the physical exchange happened. */
  confirmedBy: string[];
}

export type TransitionResult =
  | {
      ok: true;
      next: SwapState;
      /** Book(s) should become available again. */
      releaseBooks: boolean;
      /** Book(s) should be reserved for this swap. */
      reserveBooks: boolean;
      /** Book(s) should be marked as swapped (final). */
      markBooksSwapped: boolean;
    }
  | { ok: false; code: 'permission-denied' | 'failed-precondition' | 'invalid-argument'; message: string };

const fail = (
  code: 'permission-denied' | 'failed-precondition' | 'invalid-argument',
  message: string,
): TransitionResult => ({ ok: false, code, message });

export function applySwapAction(
  state: SwapState,
  action: string,
  actorUid: string,
): TransitionResult {
  if (!SWAP_ACTIONS.includes(action as SwapAction)) {
    return fail('invalid-argument', `Unknown swap action: ${action}`);
  }
  if (!actorUid) {
    return fail('permission-denied', 'You must be signed in.');
  }
  const isOwner = actorUid === state.ownerId;
  const isRequester = actorUid === state.requesterId;
  if (!isOwner && !isRequester) {
    return fail('permission-denied', 'You are not part of this swap.');
  }
  if (state.requesterId === state.ownerId) {
    return fail('failed-precondition', 'A swap cannot be between the same person.');
  }

  const unchanged = { releaseBooks: false, reserveBooks: false, markBooksSwapped: false };

  switch (action as SwapAction) {
    case 'accept':
      if (!isOwner) return fail('permission-denied', 'Only the book owner can accept.');
      if (state.status !== 'pending') {
        return fail('failed-precondition', `Cannot accept a swap that is ${state.status}.`);
      }
      return { ok: true, next: { ...state, status: 'accepted' }, ...unchanged, markBooksSwapped: true };

    case 'reject':
      if (!isOwner) return fail('permission-denied', 'Only the book owner can reject.');
      if (state.status !== 'pending') {
        return fail('failed-precondition', `Cannot reject a swap that is ${state.status}.`);
      }
      return { ok: true, next: { ...state, status: 'rejected' }, ...unchanged };

    case 'cancel':
      if (state.status === 'pending') {
        if (!isRequester) {
          return fail('permission-denied', 'Only the requester can cancel a pending request.');
        }
        return { ok: true, next: { ...state, status: 'cancelled' }, ...unchanged };
      }
      if (state.status === 'accepted' || state.status === 'inProgress') {
        return {
          ok: true,
          next: { ...state, status: 'cancelled', confirmedBy: [] },
          ...unchanged,
          releaseBooks: true,
        };
      }
      return fail('failed-precondition', `Cannot cancel a swap that is ${state.status}.`);

    case 'start':
      if (state.status !== 'accepted') {
        return fail('failed-precondition', `Cannot start a swap that is ${state.status}.`);
      }
      return { ok: true, next: { ...state, status: 'inProgress' }, ...unchanged };

    case 'confirmComplete': {
      if (state.status !== 'inProgress' && state.status !== 'accepted') {
        return fail('failed-precondition', `Cannot complete a swap that is ${state.status}.`);
      }
      const confirmedBy = state.confirmedBy.includes(actorUid)
        ? state.confirmedBy
        : [...state.confirmedBy, actorUid];
      return {
        ok: true,
        next: { ...state, status: 'completed', confirmedBy },
        ...unchanged,
        markBooksSwapped: true,
      };
    }
  }
}

// ---------------------------------------------------------------------------
// Creating a swap request
// ---------------------------------------------------------------------------

export interface BookForSwap {
  ownerId: string;
  status: string;
  listingType: string; // 'swap' | 'sale' | 'both'
}

export interface CreateSwapInput {
  requesterId: string;
  book: BookForSwap | null;
  offeredBook?: BookForSwap | null;
  offeredBookId?: string | null;
  hasActiveRequestForSameBook: boolean;
}

export function validateCreateSwap(
  input: CreateSwapInput,
): { ok: true } | { ok: false; code: 'not-found' | 'permission-denied' | 'failed-precondition' | 'already-exists'; message: string } {
  if (!input.requesterId) {
    return { ok: false, code: 'permission-denied', message: 'You must be signed in.' };
  }
  if (!input.book) {
    return { ok: false, code: 'not-found', message: 'That book does not exist.' };
  }
  if (input.book.ownerId === input.requesterId) {
    return { ok: false, code: 'failed-precondition', message: 'You cannot request your own book.' };
  }
  if (input.book.status !== 'available') {
    return { ok: false, code: 'failed-precondition', message: 'This book is not available right now.' };
  }
  if (input.book.listingType !== 'swap' && input.book.listingType !== 'both') {
    return { ok: false, code: 'failed-precondition', message: 'This book is not listed for swapping.' };
  }
  if (input.hasActiveRequestForSameBook) {
    return { ok: false, code: 'already-exists', message: 'You already have an active request for this book.' };
  }
  if (input.offeredBookId) {
    const offered = input.offeredBook;
    if (!offered) {
      return { ok: false, code: 'not-found', message: 'The book you offered does not exist.' };
    }
    if (offered.ownerId !== input.requesterId) {
      return { ok: false, code: 'permission-denied', message: 'You can only offer your own books.' };
    }
    if (offered.status !== 'available') {
      return { ok: false, code: 'failed-precondition', message: 'The book you offered is not available.' };
    }
  }
  return { ok: true };
}
