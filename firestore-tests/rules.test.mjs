// Security Rules tests: each case talks to the Firestore emulator as a real
// client would, so it proves what an attacker bypassing the app can (not) do.
// Run with:  npm run test:emulator
import { readFileSync } from "node:fs";
import { after, before, beforeEach, describe, it } from "node:test";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  Timestamp,
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from "firebase/firestore";

let env;

const inDays = (d) => Timestamp.fromMillis(Date.now() + d * 86_400_000);

const event = (overrides = {}) => ({
  ownerId: "alice",
  title: "AI Club Workshop",
  description: "Intro to LLM apps",
  location: "Room 204",
  startsAt: inDays(3),
  capacity: 40,
  ticketsIssued: 0,
  ...overrides,
});

const as = (uid) =>
  env.authenticatedContext(uid, { email: `${uid}@uni.pl` }).firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-bouncr",
    firestore: { rules: readFileSync("../firestore.rules", "utf8") },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  // Seed data with rules disabled (like the Admin SDK in Cloud Functions).
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "events/e1"), event({ ticketsIssued: 5 }));
    await setDoc(doc(db, "tickets/e1_bob"), {
      ownerId: "bob",
      eventId: "e1",
      eventTitle: "AI Club Workshop",
      status: "valid",
      signature: "sig",
      usedAt: null,
    });
    await setDoc(doc(db, "users/bob"), {
      email: "bob@uni.pl",
      displayName: "Bob",
      createdAt: Timestamp.now(),
    });
  });
});

describe("unauthenticated users", () => {
  it("cannot read anything", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "events/e1")));
    await assertFails(getDoc(doc(db, "users/bob")));
  });
});

describe("users", () => {
  it("a user creates and reads their own profile", async () => {
    const db = as("carol");
    await assertSucceeds(
      setDoc(doc(db, "users/carol"), {
        email: "carol@uni.pl",
        displayName: "Carol",
        createdAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(getDoc(doc(db, "users/carol")));
  });

  it("nobody reads someone else's profile", async () => {
    await assertFails(getDoc(doc(as("alice"), "users/bob")));
  });

  it("a profile cannot claim another email", async () => {
    await assertFails(
      setDoc(doc(as("carol"), "users/carol"), {
        email: "admin@uni.pl",
        displayName: "Carol",
        createdAt: serverTimestamp(),
      }),
    );
  });
});

describe("events", () => {
  it("any signed-in user can read events", async () => {
    await assertSucceeds(getDoc(doc(as("bob"), "events/e1")));
  });

  it("a user creates an event they own, with 0 tickets", async () => {
    await assertSucceeds(setDoc(doc(as("carol"), "events/new"), event({ ownerId: "carol" })));
  });

  it("cannot create an event for someone else", async () => {
    await assertFails(setDoc(doc(as("carol"), "events/new"), event({ ownerId: "alice" })));
  });

  it("cannot create an event with tickets already issued", async () => {
    await assertFails(
      setDoc(doc(as("carol"), "events/new"), event({ ownerId: "carol", ticketsIssued: 3 })),
    );
  });

  it("cannot create an event in the past", async () => {
    await assertFails(
      setDoc(doc(as("carol"), "events/new"), event({ ownerId: "carol", startsAt: inDays(-1) })),
    );
  });

  it("rejects invalid fields (capacity 0, unknown field)", async () => {
    const db = as("carol");
    await assertFails(setDoc(doc(db, "events/a"), event({ ownerId: "carol", capacity: 0 })));
    await assertFails(
      setDoc(doc(db, "events/b"), { ...event({ ownerId: "carol" }), isAdmin: true }),
    );
  });

  it("the owner can edit the event", async () => {
    await assertSucceeds(updateDoc(doc(as("alice"), "events/e1"), { title: "New title" }));
  });

  it("another user cannot edit the event", async () => {
    await assertFails(updateDoc(doc(as("bob"), "events/e1"), { title: "Hacked" }));
  });

  it("the owner cannot change the seat counter or the owner", async () => {
    const db = as("alice");
    await assertFails(updateDoc(doc(db, "events/e1"), { ticketsIssued: 0 }));
    await assertFails(updateDoc(doc(db, "events/e1"), { ownerId: "bob" }));
  });

  it("capacity cannot drop below tickets issued", async () => {
    await assertFails(updateDoc(doc(as("alice"), "events/e1"), { capacity: 4 }));
    await assertSucceeds(updateDoc(doc(as("alice"), "events/e1"), { capacity: 5 }));
  });

  it("events cannot be deleted", async () => {
    await assertFails(deleteDoc(doc(as("alice"), "events/e1")));
  });
});

describe("tickets", () => {
  it("the attendee reads their own ticket", async () => {
    await assertSucceeds(getDoc(doc(as("bob"), "tickets/e1_bob")));
  });

  it("the organiser of the event can read a ticket of their event", async () => {
    await assertSucceeds(getDoc(doc(as("alice"), "tickets/e1_bob")));
  });

  it("other users cannot read someone's ticket", async () => {
    await assertFails(getDoc(doc(as("carol"), "tickets/e1_bob")));
  });

  it("a user may look up their own not-yet-issued ticket", async () => {
    await assertSucceeds(getDoc(doc(as("carol"), "tickets/e1_carol")));
    await assertFails(getDoc(doc(as("carol"), "tickets/e1_dave")));
  });

  it("nobody can create a ticket from the app (no forging)", async () => {
    await assertFails(
      setDoc(doc(as("carol"), "tickets/e1_carol"), {
        ownerId: "carol",
        eventId: "e1",
        eventTitle: "AI Club Workshop",
        status: "valid",
        signature: "forged",
        usedAt: null,
      }),
    );
  });

  it("nobody can change a ticket's status from the app", async () => {
    await assertFails(updateDoc(doc(as("bob"), "tickets/e1_bob"), { status: "valid" }));
    await assertFails(updateDoc(doc(as("alice"), "tickets/e1_bob"), { status: "used" }));
  });
});
