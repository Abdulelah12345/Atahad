# Walking commitments — backend contract

Implemented for **personal habits only**, with a daily steps total (not a session delta).
The mobile Health Connect / HealthKit bridge and its UI are documented in `walking-ui.md`.
No external health service is called by the backend. Existing TIMER commitments remain separate.

## Activation

1. Mobile checks availability, requests permission and attempts to read today's aggregate steps.
2. `PUT /api/v1/walking/connection` reports the outcome:

```json
{"source":"HEALTH_CONNECT","deviceId":"installation-uuid","status":"READY","readDay":"2026-10-24","stepsRead":0}
```

Sources: `HEALTH_CONNECT`, `HEALTH_KIT`. Statuses: `READY`, `UNAVAILABLE`, `NEEDS_PERMISSION`, `UNKNOWN`.
Zero steps is a successful read; an empty/ambiguous HealthKit result should be `UNKNOWN`, not a guessed permission denial.
`GET /api/v1/walking/connection` also returns `NOT_CONNECTED` or `CHECK_REQUIRED` after 24 hours.
The device identifier should be an app installation ID, not a hardware identifier.

3. Use the existing `POST /api/v1/habit/add`, with these additional fields:

```json
{"title":"المشي اليومي","proofMethod":"STEPS","targetSteps":5000,"stepEvidenceMode":"HEALTH_DATA","timesPerWeek":7,"baseAmount":5}
```

`HEALTH_DATA` requires a READY check within the last 24 hours.
`SCREENSHOT` can be selected before activation without a working health connection.
Target range: 100–100000 steps. Target and evidence mode are immutable after activation.
`timesPerWeek` retains the existing habit scheduling policy: a successful day is one completion, up to the weekly requirement.

## Synchronization

`POST /api/v1/walking/weeks/{weekId}/sync`:

```json
{"day":"2026-10-24","total":5300,"source":"HEALTH_CONNECT","deviceId":"installation-uuid","zoneId":"Asia/Riyadh","observedAt":"2026-10-24T21:30:00"}
```

* All activity-day boundaries and timestamps in this first release use **Asia/Riyadh**, matching the existing weekly settlement calendar. Mobile must query health totals for these boundaries, even when travelling. Arbitrary phone time zones are rejected.
* `observedAt` is the time the daily aggregate was read, expressed in Riyadh time. It may be on the following day, cannot be in the future, and must be within the last 24 hours.
* Replace the saved total with a newer observation; never add daily totals together. Ignore older observations, reject different totals with the same timestamp, and allow corrections downward before completion.
* Source and installation must match the connection. One source/installation per day prevents combining phone and watch totals twice; native aggregation must already deduplicate its underlying sources.
* The proof uses the existing acceptance guard, evidence decision and completion/points services. A retry cannot award another completion. An accepted day remains accepted if health data is later corrected downward, consistent with existing proof acceptance policy.
* A successful sync refreshes the connection check. Revocation/unavailability should be reported with the connection endpoint; cached READY does not prove ongoing permission.

`GET /api/v1/walking/weeks/{weekId}/progress?day=2026-10-24` returns target, total, last sync, proof ID, status and sync deadline. No reading returns `totalSteps: null`; a real zero remains `0`.
States: `AWAITING_SYNC`, `IN_PROGRESS`, `ACCEPTED`, `ESCALATED`, `REJECTED`, `SYNC_WINDOW_ENDED`, `COVERED_BY_EXCUSE`.

## Delayed data and screenshot review

For each day D, accept data until **D+2 at 00:00 Riyadh** (one full day after D ends). Future dates and older submissions are rejected.
Weekly penalty evaluation includes that extra day. Sunday's new week starts normally; Saturday's step week is finalized on Monday, with one combined member level update across that week's commitments.
Step weeks with screenshots awaiting admin review remain unsettled; review delays do not consume a grace day or produce a penalty for the reserved day. Other missed days may still be assessed.
After the grace window, missing data follows existing grace-day/penalty policy. This is a bounded sync allowance, not an unlimited exemption for technical outages.

`POST /api/v1/walking/weeks/{weekId}/screenshot` accepts:

```json
{"day":"2026-10-24","imageData":"data:image/png;base64,..."}
```

It is available both for screenshot commitments and as a fallback for health-data commitments during the submission window.
PNG/JPEG only, maximum 3,000,000 encoded characters and 20 million pixels. A valid image is **not** proof of walking by itself.
It is escalated to the existing admin queue; the reviewer must check the full date and that the day's total meets the displayed target. Image content is stored privately in proof evidence, not public uploads or proof summary fields.
One screenshot submission per day; use the existing objection path after rejection. The server never converts missing steps into timer minutes.

## Security and trust boundary

All endpoints require MEMBER access, derive member ID from authentication and check week ownership.
Existing locked members can still synchronize/check connection/upload a walking screenshot during its allowed window, so another pending penalty does not block evidence. Banned/deactivated account restrictions remain in force.
Member and week row locks plus a unique `(member_id, activity_day)` constraint serialize concurrent updates. Existing acceptance locking prevents proof/excuse double credit.

**`DEVICE_REPORTED` is explicit:** the server validates ownership, dates, payloads and duplicates, but cannot attest that an integer sent by a modified mobile client came from HealthKit/Health Connect. This implementation does not claim fraud-proof verification. Native device attestation or additional review would be a separate enhancement.
Only aggregate steps and connection metadata are stored, not raw motion samples or location traces.
The two new tables cascade deletion when their member account is deleted.

## Database and verification

New entities: `StepConnection`, `DailySteps`. Added fields: `Commitment.targetSteps`, `Commitment.stepEvidenceMode`, `CommitmentWeek.stepsSettlementPending`.
For databases managed with explicit migrations, review `docs/sql/20261026-walking-steps.sql` before deployment. This work does not run migrations against user data.
Tests use an isolated H2 database and mock external dependencies. The repository's full application context test still depends on the user's configured database and is excluded from isolated verification.

Verified on 2026-10-26: **248 tests passed, zero failures/errors**, using `-Dtest=*,!AtahadApplicationTests`.
This includes a real local HTTP server exercising preflight → habit creation → daily sync → one completion/10 points,
repeated and simultaneous requests, screenshot review, late Saturday data, weekly settlement, permissions, and account-data deletion.
The native bridge and UI were subsequently added; no physical-device sensor test has been performed yet (see `walking-ui.md`).
