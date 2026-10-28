import { test } from 'node:test';
import assert from 'node:assert/strict';
import { checkRateLimit } from './rateLimit';
import { messageNotification, swapNotification } from './notificationBuilder';

test('allows up to the limit then blocks, then resets after the window', () => {
  let s = undefined as ReturnType<typeof checkRateLimit>['next'] | undefined;
  for (let i = 0; i < 3; i++) {
    const r = checkRateLimit(s, 1000 + i, 3, 60_000);
    assert.equal(r.allowed, true);
    s = r.next;
  }
  const blocked = checkRateLimit(s, 2000, 3, 60_000);
  assert.equal(blocked.allowed, false);
  assert.ok(blocked.retryAfterSeconds > 0);
  assert.equal(checkRateLimit(s, 1000 + 60_000, 3, 60_000).allowed, true);
});

test('notification builders produce short, safe text', () => {
  const n = swapNotification('requested', 'Clean Code', 'Alice');
  assert.equal(n.type, 'swap');
  assert.match(n.body, /Alice/);
  const m = messageNotification('Bob', 'x'.repeat(500));
  assert.equal(m.body.length, 120);
});
