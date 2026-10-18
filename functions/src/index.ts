/**
 * Bouncr Cloud Functions.
 *
 * Every decision that must be trusted runs here, never in the app:
 *  - issueTicket:    seat check + ticket creation in one transaction
 *  - validateTicket: signature check + one-time check-in in one transaction
 *  - cancelTicket:   frees the seat in one transaction
 *
 * The Admin SDK bypasses Firestore Security Rules, which forbid the app from
 * writing tickets or the seat counter at all.
 */
import type { Firestore, Timestamp } from "firebase-admin/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";

import { withContentionRetry } from "./retry";
import { parseCode, sign, ticketIdFor, verify } from "./ticket_code";

/**
 * The Admin SDK (gRPC) is loaded on first use instead of at import time:
 * deployment / emulator discovery only needs the function definitions, and
 * cold starts get faster.
 */
let firestore: Firestore | undefined;
function db(): Firestore {
  if (!firestore) {
    const { initializeApp, getApps } = require("firebase-admin/app") as typeof import("firebase-admin/app");
    const { getFirestore } = require("firebase-admin/firestore") as typeof import("firebase-admin/firestore");
    if (getApps().length === 0) initializeApp();
    firestore = getFirestore();
  }
  return firestore;
}

function fieldValue(): typeof import("firebase-admin/firestore").FieldValue {
  return (require("firebase-admin/firestore") as typeof import("firebase-admin/firestore")).FieldValue;
}

// Same region as the Firestore database (Warsaw).
setGlobalOptions({ region: "europe-central2", maxInstances: 5 });

/** HMAC key. In the emulator it is read from functions/.secret.local. */
const signingSecret = defineSecret("TICKET_SIGNING_SECRET");

type TicketStatus = "valid" | "used" | "cancelled";

interface TicketDoc {
  ownerId: string;
  eventId: string;
  eventTitle: string;
  status: TicketStatus;
  signature: string;
  usedAt: Timestamp | null;
}

interface EventDoc {
  ownerId: string;
  title: string;
  startsAt: Timestamp;
  capacity: number;
  ticketsIssued: number;
}

function requireUid(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please log in first.");
  return uid;
}

function requireEventId(data: unknown): string {
  const eventId = (data as { eventId?: unknown } | null)?.eventId;
  if (typeof eventId !== "string" || !/^[A-Za-z0-9]{1,128}$/.test(eventId)) {
    throw new HttpsError("invalid-argument", "A valid eventId is required.");
  }
  return eventId;
}

const eventRef = (id: string) => db().collection("events").doc(id);
const ticketRef = (id: string) => db().collection("tickets").doc(id);

/**
 * RSVP: issues a signed ticket for the caller.
 * Idempotent: a second call returns the existing ticket.
 */
export const issueTicket = onCall({ secrets: [signingSecret] }, async (request) => {
  const uid = requireUid(request);
  const eventId = requireEventId(request.data);
  const ticketId = ticketIdFor(eventId, uid);

  return withContentionRetry(() => db().runTransaction(async (tx) => {
    const [eventSnap, ticketSnap] = await Promise.all([
      tx.get(eventRef(eventId)),
      tx.get(ticketRef(ticketId)),
    ]);
    if (!eventSnap.exists) throw new HttpsError("not-found", "This event no longer exists.");
    const event = eventSnap.data() as EventDoc;

    const existing = ticketSnap.data() as TicketDoc | undefined;
    if (existing && existing.status !== "cancelled") {
      return { ticketId, status: existing.status, created: false };
    }
    if (event.startsAt.toMillis() <= Date.now()) {
      throw new HttpsError("failed-precondition", "This event has already started.");
    }
    if (event.ticketsIssued >= event.capacity) {
      throw new HttpsError("resource-exhausted", "Sorry, this event is sold out.");
    }

    const ticket: TicketDoc = {
      ownerId: uid,
      eventId,
      eventTitle: event.title,
      status: "valid",
      signature: sign(ticketId, signingSecret.value()),
      usedAt: null,
    };
    tx.set(ticketRef(ticketId), ticket);
    tx.update(eventRef(eventId), { ticketsIssued: fieldValue().increment(1) });
    return { ticketId, status: ticket.status, created: true };
  }));
});

type ScanResult = "admitted" | "already_used" | "cancelled" | "wrong_event" | "invalid";

/**
 * Door check-in: only the organiser of [eventId] may call it.
 * A valid ticket is marked as used exactly once.
 */
export const validateTicket = onCall({ secrets: [signingSecret] }, async (request) => {
  const uid = requireUid(request);
  const eventId = requireEventId(request.data);

  const event = await eventRef(eventId).get();
  if (!event.exists) throw new HttpsError("not-found", "This event no longer exists.");
  if ((event.data() as EventDoc).ownerId !== uid) {
    throw new HttpsError("permission-denied", "Only the organiser can check tickets in.");
  }

  const parsed = parseCode((request.data as { code?: unknown }).code);
  if (!parsed || !verify(parsed.ticketId, parsed.signature, signingSecret.value())) {
    return { result: "invalid" as ScanResult };
  }
  if (parsed.eventId !== eventId) return { result: "wrong_event" as ScanResult };

  const outcome = await withContentionRetry(() => db().runTransaction(async (tx) => {
    const snap = await tx.get(ticketRef(parsed.ticketId));
    if (!snap.exists) return { result: "invalid" as ScanResult };
    const ticket = snap.data() as TicketDoc;
    if (ticket.signature !== parsed.signature) return { result: "invalid" as ScanResult };
    if (ticket.status === "cancelled") {
      return { result: "cancelled" as ScanResult, ownerId: ticket.ownerId };
    }
    if (ticket.status === "used") {
      return {
        result: "already_used" as ScanResult,
        ownerId: ticket.ownerId,
        usedAt: ticket.usedAt?.toDate().toISOString(),
      };
    }
    tx.update(snap.ref, { status: "used", usedAt: fieldValue().serverTimestamp() });
    return { result: "admitted" as ScanResult, ownerId: ticket.ownerId };
  }));

  // The attendee's uid stays on the server; only their display name is returned.
  const { result, ownerId, usedAt } = outcome as {
    result: ScanResult;
    ownerId?: string;
    usedAt?: string;
  };
  let attendeeName: string | null = null;
  if (ownerId) {
    const profile = await db().collection("users").doc(ownerId).get();
    attendeeName = (profile.get("displayName") as string | undefined) ?? null;
  }
  return { result, attendeeName, usedAt: usedAt ?? null };
});

/** Cancels the caller's unused ticket and frees the seat. */
export const cancelTicket = onCall(async (request) => {
  const uid = requireUid(request);
  const eventId = requireEventId(request.data);
  const ticketId = ticketIdFor(eventId, uid);

  return withContentionRetry(() => db().runTransaction(async (tx) => {
    const snap = await tx.get(ticketRef(ticketId));
    if (!snap.exists) throw new HttpsError("not-found", "You have no ticket for this event.");
    const ticket = snap.data() as TicketDoc;
    if (ticket.status === "used") {
      throw new HttpsError("failed-precondition", "A used ticket cannot be cancelled.");
    }
    if (ticket.status === "cancelled") return { ticketId, status: "cancelled" };

    tx.update(snap.ref, { status: "cancelled" });
    tx.update(eventRef(eventId), { ticketsIssued: fieldValue().increment(-1) });
    return { ticketId, status: "cancelled" };
  }));
});
