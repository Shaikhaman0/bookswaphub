
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import * as logger from 'firebase-functions/logger';

import { db, requireAuth } from './shared';
import {
  AiRequestError,
  buildSystemPrompt,
  callGrok,
  extractKeywords,
  validateMessages,
  type ListingForPrompt,
} from './core/aiAssistant';

import {
  checkRateLimit,
  type RateLimitState,
} from './core/rateLimit';

const XAI_API_KEY = defineSecret('XAI_API_KEY');

export const aiAssistant = onCall(
  {
    secrets: [XAI_API_KEY],
    timeoutSeconds: 45,
  },
  async (request) => {
    // 1. Require an authenticated user.
    const uid = requireAuth(request);

    // 2. Validate the conversation messages.
    let messages;

    try {
      messages = validateMessages(request.data?.messages);
    } catch (error) {
      if (error instanceof AiRequestError) {
        throw new HttpsError(error.code, error.message);
      }

      logger.error('AI message validation failed', {
        errorName:
          error instanceof Error ? error.name : typeof error,
      });

      throw new HttpsError(
        'invalid-argument',
        'The submitted messages are invalid.',
      );
    }

    // 3. Enforce the per-user hourly request limit.
    const configuredLimit = Number(
      process.env.AI_RATE_LIMIT_PER_HOUR ?? 30,
    );

    const limit =
      Number.isSafeInteger(configuredLimit) && configuredLimit > 0
        ? configuredLimit
        : 30;

    const rateLimitRef = db.doc(`rateLimits/ai_${uid}`);

    let allowed;

    try {
      allowed = await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(rateLimitRef);

        const result = checkRateLimit(
          snapshot.exists
            ? (snapshot.data() as RateLimitState)
            : null,
          Date.now(),
          limit,
          3_600_000,
        );

        if (result.allowed) {
          transaction.set(rateLimitRef, result.next);
        }

        return result;
      });
    } catch (error) {
      logger.error('AI rate-limit check failed', {
        errorName:
          error instanceof Error ? error.name : typeof error,
      });

      throw new HttpsError(
        'unavailable',
        'The AI service is temporarily unavailable.',
      );
    }

    if (!allowed.allowed) {
      throw new HttpsError(
        'resource-exhausted',
        `Too many questions. Try again in ${Math.ceil(
          allowed.retryAfterSeconds / 60,
        )} minute(s).`,
      );
    }

    // 4. Find available books related to the latest user message.
    const lastUserMessage = messages[messages.length - 1].content;
    const keywords = extractKeywords(lastUserMessage, 10);

    let listings: (ListingForPrompt & { id: string })[] = [];

    if (keywords.length > 0) {
      try {
        const snapshot = await db
          .collection('books')
          .where('status', '==', 'available')
          .where('searchKeywords', 'array-contains-any', keywords)
          .limit(8)
          .get();

        listings = snapshot.docs.map((document) => {
          const book = document.data();

          return {
            id: document.id,
            title: String(book.title ?? ''),
            author: String(book.author ?? ''),
            category: String(book.category ?? ''),
            condition: String(book.condition ?? ''),
            listingType: String(book.listingType ?? ''),
            price:
              typeof book.price === 'number' ? book.price : null,
            location: String(book.location ?? ''),
          };
        });
      } catch (error) {
        logger.error('AI book listing lookup failed', {
          errorName:
            error instanceof Error ? error.name : typeof error,
        });

        throw new HttpsError(
          'unavailable',
          'Could not retrieve book listings. Please try again.',
        );
      }
    }

    // 5. Call the Grok API.
    try {
      const apiKey = XAI_API_KEY.value();

      if (!apiKey.trim()) {
        logger.error('XAI_API_KEY is empty or unavailable');

        throw new HttpsError(
          'failed-precondition',
          'The AI service is not configured correctly.',
        );
      }

      const model = process.env.AI_MODEL || 'grok-4.7';

      const reply = await callGrok({
        apiKey,
        model,
        system: buildSystemPrompt(listings),
        messages,
        fetchFn: (url, init) => fetch(url, init),
      });

      logger.info('AI request completed successfully', {
        model,
        listingCount: listings.length,
      });

      return {
        reply,
        listings: listings.map((listing) => ({
          id: listing.id,
          title: listing.title,
          author: listing.author,
        })),
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      // Log diagnostic details without logging secrets or request headers.
      const rawMessage =
        error instanceof Error ? error.message : 'Unknown error';

      const safeMessage = rawMessage
        .replace(/Bearer\s+\S+/gi, 'Bearer [REDACTED]')
        .replace(/xai-[A-Za-z0-9_-]+/gi, '[REDACTED_API_KEY]')
        .slice(0, 400);

      logger.error('aiAssistant Grok request failed', {
        errorName:
          error instanceof Error ? error.name : typeof error,
        isAiRequestError: error instanceof AiRequestError,
        message: safeMessage,
      });

      if (error instanceof AiRequestError) {
        throw new HttpsError(error.code, error.message);
      }

      throw new HttpsError(
        'unavailable',
        'The AI service is temporarily unavailable.',
      );
    }
  },
);
