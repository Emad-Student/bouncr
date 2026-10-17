// End-to-end tests of the Cloud Functions against the full Emulator Suite
// (Auth + Firestore + Functions). Run with:  npm run test:integration
//
// The most important case: many students RSVP for the last seats at the same
// moment, and the transaction must hand out exactly `capacity` tickets.
import { strict as assert } from "node:assert";
import { before, describe, it } from "node:test";

const PROJECT = "demo-bouncr";
const REGION = "europe-central2";
const AUTH = "http://127.0.0.1:9099";
const FIRESTORE = `http://127.0.0.1:8080/v1/projects/${PROJECT}/databases/(default)/documents`;
const FUNCTIONS = `http://127.0.0.1:5001/${PROJECT}/${REGION}`;

async function signUp(email) {
  const res = await fetch(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password: "secret123", returnSecureToken: true }),
  });
  const body = await res.json();
  return { token: body.idToken, uid: body.localId };
}

/** Seeds an event, bypassing Security Rules like an admin would. */
async function createEvent({ ownerId, capacity, startsInDays = 2 }) {
  const startsAt = new Date(Date.now() + startsInDays * 86_400_000).toISOString();
  const res = await fetch(`${FIRESTORE}/events`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: "Bearer owner" },
    body: JSON.stringify({
      fields: {
        ownerId: { stringValue: ownerId },
        title: { stringValue: "Integration test event" },
        description: { stringValue: "" },
        location: { stringValue: "Lab" },
        startsAt: { timestampValue: startsAt },
        capacity: { integerValue: String(capacity) },
        ticketsIssued: { integerValue: "0" },
      },
    }),
  });
  return (await res.json()).name.split("/").pop();
}

async function readDoc(path) {
  const res = await fetch(`${FIRESTORE}/${path}`, { headers: { Authorization: "Bearer owner" } });
  return res.ok ? (await res.json()).fields : null;
}

async function call(name, data, token) {
  const res = await fetch(`${FUNCTIONS}/${name}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  const body = await res.json();
  return res.ok ? { ok: true, data: body.result } : { ok: false, status: body.error?.status };
}

let organiser;
before(async () => {
  organiser = await signUp(`organiser-${Date.now()}@uni.pl`);
});

describe("issueTicket", () => {
  it("never overbooks: 20 simultaneous RSVPs for 5 seats → exactly 5 tickets", async () => {
    const eventId = await createEvent({ ownerId: organiser.uid, capacity: 5 });
    const students = await Promise.all(
      Array.from({ length: 20 }, (_, i) => signUp(`student${i}-${Date.now()}@uni.pl`)),
    );

    const results = await Promise.all(
      students.map((s) => call("issueTicket", { eventId }, s.token)),
    );

    const issued = results.filter((r) => r.ok).length;
    const soldOut = results.filter((r) => r.status === "RESOURCE_EXHAUSTED").length;
    assert.equal(issued, 5, "exactly capacity tickets are issued");
    assert.equal(soldOut, 15, "everyone else gets 'sold out'");

    const event = await readDoc(`events/${eventId}`);
    assert.equal(event.ticketsIssued.integerValue, "5", "seat counter matches");
  });

  it("is idempotent: the same student asking twice keeps one seat", async () => {
    const eventId = await createEvent({ ownerId: organiser.uid, capacity: 3 });
    const student = await signUp(`twice-${Date.now()}@uni.pl`);

    const [a, b] = await Promise.all([
      call("issueTicket", { eventId }, student.token),
      call("issueTicket", { eventId }, student.token),
    ]);
    assert.ok(a.ok && b.ok);
    assert.equal(a.data.ticketId, b.data.ticketId);
    const event = await readDoc(`events/${eventId}`);
    assert.equal(event.ticketsIssued.integerValue, "1");
  });

  it("rejects callers who are not signed in", async () => {
    const eventId = await createEvent({ ownerId: organiser.uid, capacity: 3 });
    const r = await call("issueTicket", { eventId });
    assert.equal(r.status, "UNAUTHENTICATED");
  });
});

describe("validateTicket and cancelTicket", () => {
  it("admits once, then reports 'already used'; forged codes are invalid", async () => {
    const eventId = await createEvent({ ownerId: organiser.uid, capacity: 3 });
    const student = await signUp(`door-${Date.now()}@uni.pl`);
    const { data } = await call("issueTicket", { eventId }, student.token);
    const ticket = await readDoc(`tickets/${data.ticketId}`);
    const code = `BNCR1.${data.ticketId}.${ticket.signature.stringValue}`;

    const notOrganiser = await call("validateTicket", { eventId, code }, student.token);
    assert.equal(notOrganiser.status, "PERMISSION_DENIED");

    const forged = await call(
      "validateTicket",
      { eventId, code: `${code.slice(0, -6)}AAAAAA` },
      organiser.token,
    );
    assert.equal(forged.data.result, "invalid");

    const first = await call("validateTicket", { eventId, code }, organiser.token);
    assert.equal(first.data.result, "admitted");
    const second = await call("validateTicket", { eventId, code }, organiser.token);
    assert.equal(second.data.result, "already_used");

    const cancelUsed = await call("cancelTicket", { eventId }, student.token);
    assert.equal(cancelUsed.status, "FAILED_PRECONDITION");
  });

  it("cancelling frees the seat for someone else", async () => {
    const eventId = await createEvent({ ownerId: organiser.uid, capacity: 1 });
    const a = await signUp(`a-${Date.now()}@uni.pl`);
    const b = await signUp(`b-${Date.now()}@uni.pl`);

    assert.ok((await call("issueTicket", { eventId }, a.token)).ok);
    assert.equal((await call("issueTicket", { eventId }, b.token)).status, "RESOURCE_EXHAUSTED");
    assert.ok((await call("cancelTicket", { eventId }, a.token)).ok);
    assert.ok((await call("issueTicket", { eventId }, b.token)).ok, "seat was freed");
  });
});
