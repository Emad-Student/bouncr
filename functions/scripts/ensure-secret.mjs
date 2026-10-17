// Creates functions/.secret.local with a random ticket-signing key if it does
// not exist yet, so a fresh clone works with the emulator without manual steps.
// The file is git-ignored; in production the key lives in Secret Manager.
import { randomBytes } from "node:crypto";
import { existsSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const file = join(dirname(fileURLToPath(import.meta.url)), "..", ".secret.local");
if (!existsSync(file)) {
  writeFileSync(file, `TICKET_SIGNING_SECRET=${randomBytes(32).toString("base64url")}\n`);
  console.log("Created functions/.secret.local with a new random signing key.");
}
