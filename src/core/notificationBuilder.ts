// Builds notification text for server-generated events (pure, testable).

export interface NotificationPayload {
  type: 'swap' | 'message' | 'wishlist' | 'review' | 'system';
  title: string;
  body: string;
  actionRoute: string;
}

export function swapNotification(
  event: 'requested' | 'accepted' | 'rejected' | 'cancelled' | 'started' | 'completed' | 'awaitingConfirm',
  bookTitle: string,
  actorName: string,
): NotificationPayload {
  const t = bookTitle.slice(0, 80);
  const n = actorName.slice(0, 60) || 'Someone';
  const map: Record<string, [string, string]> = {
    requested: ['New swap request', `${n} wants to swap for "${t}".`],
    accepted: ['Swap accepted', `${n} accepted the swap for "${t}".`],
    rejected: ['Swap declined', `${n} declined the swap for "${t}".`],
    cancelled: ['Swap cancelled', `${n} cancelled the swap for "${t}".`],
    started: ['Swap in progress', `${n} marked the swap for "${t}" as in progress.`],
    awaitingConfirm: ['Confirm the exchange', `${n} confirmed the exchange of "${t}". Please confirm too.`],
    completed: ['Swap completed', `The swap for "${t}" is complete. You can leave a review.`],
  };
  const [title, body] = map[event];
  return { type: 'swap', title, body, actionRoute: '/swaps' };
}

export function messageNotification(senderName: string, text: string): NotificationPayload {
  return {
    type: 'message',
    title: `New message from ${senderName.slice(0, 60) || 'someone'}`,
    body: text.slice(0, 120),
    actionRoute: '/chat',
  };
}
