// One-off script to seed (or update) the `calculators` collection that
// apps/mobile's catalog screen reads from. Firestore rules only let admins
// write to that collection (`firestore.rules`: `allow write: if isAdmin()`),
// and there's no admin-panel UI to do this through yet (that's M5) — so for
// now this runs with the Admin SDK, which bypasses security rules entirely,
// same as everything else under server/.
//
// Usage (from server/, with .env already set up per README.md):
//   node scripts/seed-calculators.js
//
// Safe to re-run: each calculator is written with a fixed, human-readable
// document ID (see calculators.seed.json's "id" field) via `.set()`, so
// re-running this after editing the JSON just overwrites those same docs —
// it won't create duplicates.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

import 'dotenv/config';

import { getFirebaseAdmin } from '../src/firebaseAdmin.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function main() {
  const seedPath = path.join(__dirname, 'calculators.seed.json');
  const { calculators } = JSON.parse(readFileSync(seedPath, 'utf8'));

  const app = getFirebaseAdmin();
  const db = app.firestore();

  for (const calculator of calculators) {
    const { id, ...data } = calculator;
    await db.collection('calculators').doc(id).set(data);
    console.log(`Seeded calculator: ${id} (${data.name})`);
  }

  console.log(`Done — seeded ${calculators.length} calculator(s).`);
}

main().catch((error) => {
  console.error('Seeding failed:', error);
  process.exitCode = 1;
});
