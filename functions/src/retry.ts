import { HttpsError } from "firebase-functions/v2/https";

/**
 * Firestore retries a contended transaction a few times on its own, but when
 * many students RSVP for the same event at the same second the transaction can
 * still end with ABORTED ("lock timeout"). Retrying with exponential backoff
 * and random jitter spreads the attempts out, so every caller ends with either
 * a ticket or a clear "sold out" instead of an internal error.
 */
/** gRPC status code of an aborted (contended) Firestore transaction. */
export const ABORTED = 10;
export const MAX_ATTEMPTS = 8;

export async function withContentionRetry<T>(
  work: () => Promise<T>,
  sleep: (ms: number) => Promise<void> = (ms) => new Promise((r) => setTimeout(r, ms)),
): Promise<T> {
  for (let attempt = 1; ; attempt++) {
    try {
      return await work();
    } catch (error) {
      const aborted = (error as { code?: unknown }).code === ABORTED;
      if (!aborted) throw error;
      if (attempt >= MAX_ATTEMPTS) {
        throw new HttpsError(
          "aborted",
          "Lots of people are getting tickets right now. Please try again in a moment.",
        );
      }
      await sleep(Math.min(2000, 50 * 2 ** attempt) * (0.5 + Math.random()));
    }
  }
}
