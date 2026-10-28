import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { db, FieldValue, pushToUser } from './shared';
import { messageNotification } from './core/notificationBuilder';

/** Trusted side-effects of a new chat message: conversation summary, unread count, notification, push. */
export const onMessageCreated = onDocumentCreated('conversations/{conversationId}/messages/{messageId}', async (event) => {
  const msg = event.data?.data();
  if (!msg) return;
  const convRef = db.doc(`conversations/${event.params.conversationId}`);
  const conv = await convRef.get();
  if (!conv.exists) return;
  const participants: string[] = conv.data()!.participantIds ?? [];
  const senderId = String(msg.senderId);
  const text = String(msg.text ?? '');
  const others = participants.filter((p) => p !== senderId);

  const sender = await db.doc(`users/${senderId}`).get();
  const senderName = String(sender.data()?.name ?? 'Someone');

  const update: Record<string, unknown> = {
    lastMessage: text.slice(0, 200),
    lastMessageAt: msg.createdAt ?? FieldValue.serverTimestamp(),
    lastSenderId: senderId,
  };
  for (const o of others) update[`unread.${o}`] = FieldValue.increment(1);
  await convRef.update(update);

  const n = messageNotification(senderName, text);
  await Promise.all(
    others.map(async (o) => {
      await db.collection('notifications').add({ userId: o, ...n, isRead: false, createdAt: FieldValue.serverTimestamp() });
      await pushToUser(o, { title: n.title, body: n.body, route: n.actionRoute });
    }),
  );
});
