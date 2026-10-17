import { strict as assert } from "node:assert";
import { describe, it } from "node:test";

import { buildCode, parseCode, sign, ticketIdFor, verify } from "../ticket_code";

const SECRET = "test-secret-0123456789";
const TICKET = ticketIdFor("evt123", "user456");

describe("ticket codes", () => {
  it("round-trips a signed code", () => {
    const code = buildCode(TICKET, sign(TICKET, SECRET));
    const parsed = parseCode(code);
    assert.ok(parsed);
    assert.equal(parsed.ticketId, TICKET);
    assert.equal(parsed.eventId, "evt123");
    assert.equal(parsed.uid, "user456");
    assert.ok(verify(parsed.ticketId, parsed.signature, SECRET));
  });

  it("is deterministic per ticket and differs between tickets", () => {
    assert.equal(sign(TICKET, SECRET), sign(TICKET, SECRET));
    assert.notEqual(sign(TICKET, SECRET), sign(ticketIdFor("evt123", "other"), SECRET));
  });

  it("rejects a signature made with another secret (forgery)", () => {
    const forged = sign(TICKET, "attacker-guess");
    assert.equal(verify(TICKET, forged, SECRET), false);
  });

  it("rejects a valid signature moved to another ticket", () => {
    const sig = sign(TICKET, SECRET);
    assert.equal(verify(ticketIdFor("evt123", "someoneElse"), sig, SECRET), false);
  });

  it("rejects malformed codes", () => {
    for (const bad of [
      "",
      42,
      null,
      "hello",
      "BNCR2.evt_user.abcdefghijklmnopqrstuvwxyz",
      "BNCR1.evtuser.abcdefghijklmnopqrstuvwxyz",
      "BNCR1.evt_user.short",
      "BNCR1.e/vt_user.abcdefghijklmnopqrstuvwxyz",
      "BNCR1.evt_user.abc.def",
    ]) {
      assert.equal(parseCode(bad), null, String(bad));
    }
  });

  it("refuses to sign without a secret", () => {
    assert.throws(() => sign(TICKET, ""));
  });
});
