import { HttpsError } from "firebase-functions/v2/https";

/**
 * Retries work that lost a race on a contended document, with exponential
 * backoff and random jitter so competing callers spread out. Covers an
 * optimistic write whose precondition no longer holds (FAILED_PRECONDITION /
 * ALREADY_EXISTS) and an aborted transaction (ABORTED). Every caller ends with
 * a result, a business error such as "sold out", or a clear "try again".
 */
/** gRPC status codes of a lost race on a Firestore document. */
export const ALREADY_EXISTS = 6;
export const FAILED_PRECONDITION = 9;
export const ABORTED = 10;
const CONFLICT_CODES = new Set<unknown>([ALREADY_EXISTS, FAILED_PRECONDITION, ABORTED]);
export const MAX_ATTEMPTS = 30;

export async function withContentionRetry<T>(
  work: () => Promise<T>,
  sleep: (ms: number) => Promise<void> = (ms) => new Promise((r) => setTimeout(r, ms)),
): Promise<T> {
  for (let attempt = 1; ; attempt++) {
    try {
      return await work();
    } catch (error) {
      const conflict = CONFLICT_CODES.has((error as { code?: unknown }).code);
      if (!conflict) throw error;
      if (attempt >= MAX_ATTEMPTS) {
        throw new HttpsError(
          "aborted",
          "Lots of people are getting tickets right now. Please try again in a moment.",
        );
      }
      await sleep(Math.min(1000, 20 * 1.5 ** attempt) * (0.5 + Math.random()));
    }
  }
}

