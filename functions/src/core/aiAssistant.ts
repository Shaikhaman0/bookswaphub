
const XAI_API_URL = 'https://api.x.ai/v1/chat/completions';
const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const DEFAULT_MODEL = 'grok-4.7';
const GROQ_DEFAULT_MODEL = 'openai/gpt-oss-120b';
const DEFAULT_TIMEOUT_MS = 30_000;

export class AiRequestError extends Error {
  constructor(
    public readonly code:
      | 'invalid-argument'
      | 'failed-precondition'
      | 'resource-exhausted'
      | 'unavailable'
      | 'internal',
    message: string,
  ) {
    super(message);
    this.name = 'AiRequestError';
  }
}

export type ListingForPrompt = {
  id?: string;
  title?: string;
  description?: string;
  author?: string;
  category?: string;
  condition?: string;
  listingType?: string;
  price?: number | null;
  location?: string;
  status?: string;
};

export type ChatMessage = {
  role: 'system' | 'user' | 'assistant';
  content: string;
};

export type FetchLike = (
  url: string,
  init: {
    method: string;
    headers: Record<string, string>;
    body: string;
    signal?: AbortSignal;
  },
) => Promise<{
  ok: boolean;
  status: number;
  json(): Promise<unknown>;
  text?: () => Promise<string>;
}>;

export type CallGrokOptions = {
  apiKey?: string;
  model?: string;
  messages: ChatMessage[];
  system?: string;
  systemPrompt?: string;
  fetchFn?: FetchLike;
  timeoutMs?: number;
};

const STOP_WORDS = new Set([
  'a', 'an', 'the', 'and', 'or', 'but', 'if', 'then', 'else',
  'is', 'am', 'are', 'was', 'were', 'be', 'been', 'being',
  'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would',
  'can', 'could', 'should', 'may', 'might', 'must',
  'i', 'me', 'my', 'mine', 'we', 'our', 'ours', 'you', 'your',
  'yours', 'he', 'she', 'it', 'they', 'them', 'their',
  'this', 'that', 'these', 'those', 'to', 'of', 'in', 'on',
  'at', 'by', 'for', 'from', 'with', 'about', 'as', 'into',
  'what', 'which', 'who', 'whom', 'when', 'where', 'why', 'how',
  'please', 'help', 'want', 'need', 'like', 'find','books',
]);

export function extractKeywords(
  input: string,
  maxKeywords = 10,
): string[] {
  const words = input
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter(
      (word) =>
        word.length > 1 &&
        !STOP_WORDS.has(word) &&
        !/^\d+$/.test(word),
    );

  return [...new Set(words)].slice(
    0,
    Math.max(0, maxKeywords),
  );
}


export function validateMessages(messages: unknown): ChatMessage[] {
  if (!Array.isArray(messages) || messages.length === 0) {
    throw new AiRequestError(
      'invalid-argument',
      'Please provide at least one message.',
    );
  }

  const validated: ChatMessage[] = [];

  for (const item of messages) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      throw new AiRequestError(
        'invalid-argument',
        'A message has an invalid format.',
      );
    }

    const message = item as Record<string, unknown>;

    if (
      message.role !== 'user' &&
      message.role !== 'assistant'
    ) {
      throw new AiRequestError(
        'invalid-argument',
        'A message has an unsupported role.',
      );
    }

    if (
      typeof message.content !== 'string' ||
      !message.content.trim()
    ) {
      throw new AiRequestError(
        'invalid-argument',
        'A message cannot be empty.',
      );
    }

    if (message.content.length > 8_000) {
      throw new AiRequestError(
        'invalid-argument',
        'A message is too long.',
      );
    }

    validated.push({
      role: message.role,
      content: message.content.trim(),
    });
  }

  // Keep only the latest 10 messages.
  const recent = validated.slice(-10);

  // The conversation must begin with a user message.
  const firstUserIndex = recent.findIndex(
    (message) => message.role === 'user',
  );

  if (firstUserIndex === -1) {
    throw new AiRequestError(
      'invalid-argument',
      'At least one user message is required.',
    );
  }

  return recent.slice(firstUserIndex);
}

export function buildSystemPrompt(
  listings: ListingForPrompt[] = [],
): string {
  const listingContext = listings
    .slice(0, 20)
    .map((listing, index) => {
      const details = [
        listing.id ? `ID: ${listing.id}` : undefined,
        listing.title ? `Title: ${listing.title}` : undefined,
        listing.author ? `Author: ${listing.author}` : undefined,
        listing.category ? `Category: ${listing.category}` : undefined,
        listing.condition
          ? `Condition: ${listing.condition}`
          : undefined,
        listing.listingType
          ? `Listing type: ${listing.listingType}`
          : undefined,
        listing.price != null
          ? `Price: ${listing.price}`
          : undefined,
        listing.location
          ? `Location: ${listing.location}`
          : undefined,
        listing.status ? `Status: ${listing.status}` : undefined,
        listing.description
          ? `Description: ${listing.description.slice(0, 300)}`
          : undefined,
      ].filter(Boolean);

      return `${index + 1}. ${details.join('; ')}`;
    })
    .join('\n');

  return [
    'You are the AI book assistant for Book Swap Hub.',
    'Help users discover books, understand listings, and use the app.',
    'Be friendly, accurate, and concise.',
    'Never invent listings, book details, prices, or availability.',
    'Never invent app capabilities.',
    'Use the provided listing context when relevant.',
    'Only recommend books supported by the available listing data.',
    'If no listing matches the user request, explicitly say: No matching listings.',
    'If information is insufficient, explain what information is missing.',
    'Never claim to have completed an app action unless it was actually completed.',
    listingContext
      ? `Available book listings:\n${listingContext}`
      : 'No matching listings are available in the provided context.',
  ].join('\n');
}
export function parseGrokText(data: unknown): string {
  if (!data || typeof data !== 'object') {
    throw new AiRequestError(
      'unavailable',
      'The AI service returned an invalid response.',
    );
  }

  const response = data as {
    choices?: Array<{
      message?: { content?: unknown };
    }>;
  };

  const content = response.choices?.[0]?.message?.content;

  if (typeof content === 'string' && content.trim()) {
    return content.trim();
  }

  if (Array.isArray(content)) {
    const parts = content
      .filter(
        (item): item is { type: string; text: string } =>
          !!item &&
          typeof item === 'object' &&
          'type' in item &&
          'text' in item &&
          item.type === 'text' &&
          typeof item.text === 'string',
      )
      .map((item) => item.text);

    if (parts.length > 0) {
      return parts.join('\n').trim();
    }
  }

  throw new AiRequestError(
    'unavailable',
    'The AI service returned an empty response.',
  );
}

function sanitizeProviderError(value: string): string {
  return value
    .slice(0, 1_000)
    .replace(/Bearer\s+\S+/gi, 'Bearer [REDACTED]')
    .replace(/xai-[A-Za-z0-9_-]+/gi, '[REDACTED]');
}

async function readErrorBody(
  response: Awaited<ReturnType<FetchLike>>,
): Promise<string> {
  if (typeof response.text === 'function') {
    return response.text();
  }

  // Supports existing test mocks that only implement json().
  try {
    return JSON.stringify(await response.json());
  } catch {
    return '';
  }
}

export async function callGrok(
  options: CallGrokOptions,
): Promise<string> {
  const messages = options.messages;
  const systemPrompt =
    options.system ??
    options.systemPrompt ??
    buildSystemPrompt();
  const fetchFn = options.fetchFn;

  const apiKey = options.apiKey ?? process.env.GROQ_API_KEY ?? process.env.XAI_API_KEY;
  const isGroq = (apiKey ?? '').startsWith('gsk_');
  const apiUrl = isGroq ? GROQ_API_URL : XAI_API_URL;
  let model = options.model ?? process.env.AI_MODEL;
  if (!model || (isGroq && model.startsWith('grok'))) {
    model = isGroq ? GROQ_DEFAULT_MODEL : DEFAULT_MODEL;
  }
  const timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;

  if (!apiKey) {
    throw new AiRequestError(
      'failed-precondition',
      'The AI service is not configured. Check the AI API key secret.',
    );
  }

  if (!Array.isArray(messages) || messages.length === 0) {
    throw new AiRequestError(
      'invalid-argument',
      'Please provide at least one message.',
    );
  }

  const fetchImpl: FetchLike =
    fetchFn ??
    (globalThis.fetch as unknown as FetchLike);

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetchImpl(apiUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        messages: [
          {
            role: 'system',
            content: systemPrompt,
          },
          ...messages,
        ],
        temperature: 0.7,
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      const rawBody = await readErrorBody(response);
      let providerError = rawBody;

      try {
        const body = JSON.parse(rawBody) as {
          error?: unknown;
          message?: unknown;
          code?: unknown;
        };

        if (typeof body.error === 'string') {
          providerError = body.error;
        } else if (
          body.error &&
          typeof body.error === 'object' &&
          'message' in body.error &&
          typeof body.error.message === 'string'
        ) {
          providerError = body.error.message;
        } else if (typeof body.message === 'string') {
          providerError = body.message;
        } else if (typeof body.code === 'string') {
          providerError = `Code: ${body.code}; response: ${rawBody}`;
        }
      } catch {
        // Keep the original body when the provider returns non-JSON.
      }

      providerError = sanitizeProviderError(
        providerError || 'Empty response body',
      );

      console.error('Grok API request failed', {
        status: response.status,
        model,
        providerError,
      });

      if (
        response.status === 401 ||
        response.status === 403 ||
        providerError.toLowerCase().includes('api key')
      ) {
        throw new AiRequestError(
          'failed-precondition',
          isGroq
            ? 'Groq authentication failed. Please check your Groq API key.'
            : 'Grok authentication failed. Check the XAI_API_KEY secret.',
        );
      }

      if (response.status === 404) {
        throw new AiRequestError(
          'failed-precondition',
          `The configured model (${model}) was not found. Please check your AI configuration.`,
        );
      }

      if (response.status === 429) {
        throw new AiRequestError(
          'resource-exhausted',
          'The AI service is busy or rate limited. Please retry shortly.',
        );
      }

      throw new AiRequestError(
        'unavailable',
        'The AI service is temporarily unavailable.',
      );
    }

    return parseGrokText(await response.json());
  } catch (error) {
    if (error instanceof AiRequestError) {
      throw error;
    }

    if (error instanceof Error && error.name === 'AbortError') {
      throw new AiRequestError(
        'unavailable',
        'The AI request timed out. Please try again.',
      );
    }

    console.error('Grok request could not be completed', {
      errorName:
        error instanceof Error ? error.name : 'UnknownError',
    });

    throw new AiRequestError(
      'unavailable',
      'Unable to connect to the AI service. Please try again.',
    );
  } finally {
    clearTimeout(timeout);
  }
}
