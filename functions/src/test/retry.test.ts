import { strict as assert } from "node:assert";
import { describe, it } from "node:test";

import { ABORTED, FAILED_PRECONDITION, MAX_ATTEMPTS, withContentionRetry } from "../retry";

const noSleep = async () => {};
const aborted = () => Object.assign(new Error("lock timeout"), { code: ABORTED });

describe("withContentionRetry", () => {
  it("retries aborted transactions until they succeed", async () => {
    let calls = 0;
    const result = await withContentionRetry(async () => {
      calls++;
      if (calls < 3) throw aborted();
      return "ticket";
    }, noSleep);
    assert.equal(result, "ticket");
    assert.equal(calls, 3);
  });

  it("retries an optimistic write whose precondition failed", async () => {
    let calls = 0;
    const result = await withContentionRetry(async () => {
      calls++;
      if (calls === 1) throw Object.assign(new Error("stale"), { code: FAILED_PRECONDITION });
      return "ok";
    }, noSleep);
    assert.equal(result, "ok");
    assert.equal(calls, 2);
  });

  it("does not retry other errors (e.g. sold out)", async () => {
    let calls = 0;
    await assert.rejects(
      withContentionRetry(async () => {
        calls++;
        throw Object.assign(new Error("sold out"), { code: "resource-exhausted" });
      }, noSleep),
      /sold out/,
    );
    assert.equal(calls, 1);
  });

  it("gives up with a friendly 'aborted' error after the last attempt", async () => {
    let calls = 0;
    await assert.rejects(
      withContentionRetry(async () => {
        calls++;
        throw aborted();
      }, noSleep),
      (e: { code?: string; message?: string }) =>
        e.code === "aborted" && /try again/.test(e.message ?? ""),
    );
    assert.equal(calls, MAX_ATTEMPTS);
  });
});

