/**
 * Ticket codes: what the QR contains.
 *
 * Format: `BNCR1.<ticketId>.<signature>`
 *   ticketId  = `<eventId>_<uid>` (the Firestore document id)
 *   signature = base64url(HMAC-SHA256(secret, "BNCR1." + ticketId))
 *
 * The secret exists only on the server, so the app (or anyone copying the
 * QR format) cannot produce a valid signature for a ticket that was never
 * issued. Pure functions only — unit-tested in test/ticket_code.test.ts.
 */
import { createHmac, timingSafeEqual } from "node:crypto";

export const CODE_VERSION = "BNCR1";

const ID_PATTERN = /^[A-Za-z0-9]{1,128}_[A-Za-z0-9]{1,128}$/;

export function ticketIdFor(eventId: string, uid: string): string {
  return `${eventId}_${uid}`;
}

export function sign(ticketId: string, secret: string): string {
  if (!secret) throw new Error("Signing secret is not configured");
  return createHmac("sha256", secret)
    .update(`${CODE_VERSION}.${ticketId}`)
    .digest("base64url");
}

export function buildCode(ticketId: string, signature: string): string {
  return `${CODE_VERSION}.${ticketId}.${signature}`;
}

export interface ParsedCode {
  ticketId: string;
  eventId: string;
  uid: string;
  signature: string;
}

/** Returns `null` for anything that is not a well-formed Bouncr code. */
export function parseCode(code: unknown): ParsedCode | null {
  if (typeof code !== "string" || code.length > 400) return null;
  const parts = code.trim().split(".");
  if (parts.length !== 3 || parts[0] !== CODE_VERSION) return null;
  const [, ticketId, signature] = parts;
  if (!ID_PATTERN.test(ticketId) || !/^[A-Za-z0-9_-]{20,}$/.test(signature)) {
    return null;
  }
  const [eventId, uid] = ticketId.split("_");
  return { ticketId, eventId, uid, signature };
}

/** Constant-time comparison, so the signature cannot be guessed byte by byte. */
export function verify(ticketId: string, signature: string, secret: string): boolean {
  const expected = Buffer.from(sign(ticketId, secret));
  const actual = Buffer.from(signature);
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}
