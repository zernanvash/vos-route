# VOSRoute — Realtime Push Design (Item 6, not yet implemented)

> Scope: design only. No app or backend code has been written for this. Goal: realtime
> push between the Next.js/SCM web app (dispatcher) and the Flutter driver app **without
> a persistent WebSocket**, using Firebase Cloud Messaging (FCM) in both directions.

## Current state (already in the repo)

- `main.dart` calls `Firebase.initializeApp()`; `NotificationService().init()` runs at startup.
- `NotificationService.init()` already:
  - requests notification permission,
  - fetches the FCM token via `FirebaseMessaging.instance.getToken()`,
  - registers it with Spring Boot `POST /api/dispatch/mobile/register-device` `{ fcmToken, deviceInfo }`,
  - listens on `onMessage` / `onBackgroundMessage` / `onMessageOpenedApp` and deep-links via `_navigateWithData` (already supports `/stop-detail`, `/sos`, `/budget`, `/history`, `/settings`).
- So the **mobile client side is ~80% scaffolded**. What is missing is (a) server-side send logic and (b) a place to persist the token for targeting, plus (c) the reverse direction.

## Direction A — Next.js / SCM web → Flutter driver

**Mechanism:** FCM data message sent from a server using the Firebase Admin SDK.

### Token storage and lifecycle

Two dedicated tables in Directus avoid polluting the `user` record with ephemeral tokens:

**`driver_push_tokens`**

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid (PK) | auto-generated |
| `user_id` | m2o → `user.id` | the driver whose device this is |
| `fcm_token` | string | the device token from Firebase |
| `device_info` | string | `"Android"` / `"iOS"` |
| `created_at` | timestamp | auto |
| `last_seen` | timestamp | updated on every successful push delivery (polled from FCM send response, or on token re-registration) |

**Motivation for a table (not a single field):** A driver may use multiple devices (phone replacement, tablet in the cab). When approval fires, send to **all** non-expired tokens for that driver.

**Token lifecycle — registration.** The Flutter app already calls `NotificationService._registerToken()` on:
1. App startup (`getToken()`).
2. `FirebaseMessaging.onTokenRefresh.listen(...)` — this already exists in `NotificationService.init()` (`_fcm?.onTokenRefresh.listen(_registerToken)`), so re-registration on silent rotation is covered.

**Token lifecycle — stale / dead token cleanup.** On every send-to-device by the Admin SDK, inspect the response for `"unregistered"` / `"NotRegistered"` results per token. Delete that token row from `driver_push_tokens` immediately. Without this, dead tokens accumulate silently and delivery failures go unnoticed. A periodic garbage-collection cron can sweep tokens whose `last_seen` is >30 days old as a safety net.

### Auth on registration endpoints

Mobile registration lives under Spring Boot (same as `/auth/login`), so **the request is authenticated by the driver's JWT** — only a logged-in driver can register tokens against their own `user_id`. The endpoint maps the token to the authenticated user server-side; the client does NOT send a `user_id` in the body.

If moved from Spring Boot to Directus (simplifies the dispatcher side), the Directus endpoint must check that the authenticated user matches the `user_id` in the request — enforced by the Directus permissions system (`$CURRENT_USER`) or a custom hook.

### Trigger / send path

When a dispatcher approves a DP (status → `For Dispatch` / `For Inbound`):

**Decision: Option A (Next.js approval handler calls Admin SDK directly) is the default; Option B (Directus Flow) is the fallback if DP status can change outside Next.js.**

- **For the MVP**, if the only way a DP gets approved is via the Next.js approval action, Option A is simpler — one code path, no webhook config, no extra latency.
- **If anyone ever edits DP status directly in Directus** (admin panel, bulk import, automation), then any push-trigger path that lives solely in Next.js silently misses those changes. In that case, use Option B: a Directus Flow on `post_dispatch_plan` status change → `POST` a Next.js API route (authenticated with a shared secret) → Admin SDK send.

Payload (data-only, for background delivery):
```json
{
  "type": "dp_approved",
  "planId": "<id>",
  "docNo": "<docNo>",
  "screen": "/stop-detail"
}
```

**Auth for the webhook route.** The Directus Flow → Next.js API route must authenticate with a pre-shared key (not user scoped) — it's a server-to-server call. Validate via a header like `Authorization: Bearer <configured_secret>` on the Next.js side.

**Failure handling.** The Admin SDK `sendEachForMulticast()` returns a `BatchResponse` with `successCount` and `failureCount`. Log every failure at `warn` level with the token prefix (last 4 chars for debugging without leaking). Do NOT retry automatically — the push is a wake-up signal, not a source-of-truth delivery. But a sustained failure pattern (e.g. all sends failing for 1 hour) should page. A simple heuristic: if the last 3 consecutive sends to the same token all failed, delete that token row.

### App-side handling (mostly exists)

`NotificationService` already handles foreground, background, and tap. For the new `type` values `{dp_approved, dp_dispatched, dp_updated}`, add a case in `_navigateWithData` that calls `TripProvider.fetchActiveTrip(forceRefresh: true)` so the UI reconciles. The existing `_navigateWithData` switch statement is the right place — it already handles `/stop-detail`, `/sos`, etc.; add the action-type branches there.

## Direction B — Flutter driver → Next.js / SCM web (dispatcher)

**Mechanism:** FCM Web Push from the same Firebase project, using the FCM Web SDK in the
dispatcher's browser tab.

### Dispatcher subscription

After dispatcher login, Next.js subscribes the browser via `getToken({ vapidKey: '...' })`
from the FCM Web SDK (requires a `firebase-messaging-sw.js` service worker). The token is
stored in **`dispatcher_push_tokens`**:

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid (PK) | auto-generated |
| `user_id` | m2o → `user.id` | the dispatcher |
| `fcm_web_token` | string | browser push subscription token |
| `tab_id` | string (opt) | opaque identifier for dedup (see below) |
| `created_at` | timestamp | auto |
| `last_seen` | timestamp | updated on every push or re-registration |

**Staleness — web side.** A browser tab closing does NOT automatically invalidate the token. Use two mechanisms:
1. On dispatcher **logout**, call `/api/web/unregister-fcm-token` to delete the current token.
2. On every successful Web Push delivery, update `last_seen`. A periodic cron deletes tokens where `last_seen` > 7 days (browsers unseen that long are likely stale). This is the same pattern as Direction A.

**Staleness — token cleanup on send failure.** Same as driver side: on `"NotRegistered"`/`"InvalidRegistration"` in the Admin SDK response, delete the token row immediately.

### Fan-out scope — which dispatcher gets notified?

Send the push to **all dispatcher sessions subscribed to the specific plan's assigned dispatcher(s)** — NOT broadcast to all dispatchers.

Implementation: when approving a DP, the dispatcher is recorded as `assigned_dispatcher_id` on the plan (or inferred from the `last_modified_by`). On driver events (arrival, SOS, stop update), the Next.js trigger handler resolves the plan's `assigned_dispatcher_id`, looks up all `dispatcher_push_tokens` for that user, and sends. If no dispatcher assignment exists, fall back to a configurable Directus role slug (e.g. `"dispatcher_on_duty"`) and push to all active sessions in that role.

This keeps fan-out within FCM's practical limits (Firebase free tier handles millions of tokens, but irrelevant pushes are noisy and signal-to-noise degrades feedback loops).

### Trigger

Driver actions flow through `ActionQueueService` → Directus. A Next.js API route polls or
(if Option B above) receives a Directus webhook/Flow for relevant changes:
- `post_dispatch_plan` → status `For Clearance` / `Posted` (arrival)
- `fleet_emergency_reports` → new row (SOS)
- `post_dispatch_invoices` → status changed (stop update)

The route resolves the target dispatcher(s) per fan-out above and calls `messaging.sendEachForMulticast()`.

Payload:
```json
{
  "type": "driver_arrived" | "driver_sos" | "stop_updated",
  "planId": "<id>",
  "docNo": "<docNo>",
  "dispatcherScreen": "/dispatch-plan/<id>"
}
```

### Dispatcher-side handling

The service worker receives the push, shows a notification, and on click navigates to the
relevant DP in the Next.js console. This replaces any polling the web app currently does.

## Offline / fallback

- The driver app is offline-first. An FCM push arriving while offline is queued by the FCM
  transport and delivered on reconnect; the app **must not** treat the push as truth. On open
  it triggers the normal `fetchActiveTrip()` reconciliation (already implemented). The push is
  only a wake-up signal.
- `ActionQueueService` already guarantees driver→server writes are retried/coalesced, so the
  dispatcher eventually sees the change even if its Web Push is missed.
- **Send-side failure discipline:** failures in `sendEachForMulticast()` are logged at `warn` level
  with the token prefix. They are NOT retried at the application layer — the reconciler is the
  safety net. A monitoring check (last-N-sends-all-failed) can page for investigation.

## Sequence — Direction A (DP approved)

```
Dispatcher (Next.js)                Directus                Admin SDK                 Flutter (driver)
      |  approve DP (status=For Dispatch) |                       |                          |
      |---------------------------------->|                       |                          |
      |  lookup driver PushTokens        |                       |                          |
      |  (non-expired rows for user)     |                       |                          |
      |<----------------------------------|                       |                          |
      |  messaging.sendEachForMulticast({tokens, data})           |                          |
      |---------------------------------------------------------->|                          |
      |                                                          |  FCM push (data)         |
      |                                                          |-------------------------->|
      |                                                          |  NotificationService shows|
      |                                                          |  + fetchActiveTrip()      |
      |                                                          |  (reconcile from Directus)|
      |                                                          |                          |
      | <-- inspect BatchResponse; delete NotRegistered tokens -->|                         |
```

## Sequence — Direction B (driver arrived / SOS)

```
Flutter                 ActionQueueService     Directus          Next.js API        FCM Web         Dispatcher browser
  |  markArrived enqueue  |                       |                 |                |                |
  |---------------------->|  POST (retry/coalesce) |                 |                |                |
  |                       |---------------------->|                 |                |                |
  |                       |  Directus Flow triggers Next.js route   |                |                |
  |                       |                       |---------------->|                |                |
  |                       |                       |  resolve dispatcher for plan     |                |
  |                       |                       |  lookup fcm_web_tokens for user  |                |
  |                       |                       |  messaging.sendEachForMulticast  |                |
  |                       |                       |                 |--------------->| Web Push       |
  |                       |                       |                 | inspect BatchResponse;       |
  |                       |                       |                 | delete NotRegistered tokens  |
```

## New pieces required (flag before building)

### Directus schema (needs approval — schema discipline rule)

| Collection | Fields | Purpose |
|------------|--------|---------|
| `driver_push_tokens` | `id` (uuid), `user_id` (m2o → public.users), `fcm_token` (string), `device_info` (string), `created_at`, `last_seen` | One row per driver device. Supports multi-device drivers and dead-token cleanup. |
| `dispatcher_push_tokens` | `id` (uuid), `user_id` (m2o → public.users), `fcm_web_token` (string), `tab_id` (string, nullable), `created_at`, `last_seen` | One row per browser session. Same lifecycle as driver tokens. |
| `post_dispatch_plan` (existing) | new field `assigned_dispatcher_id` (m2o → public.users, nullable) | Controls fan-out for Direction B. If null, falls back to role-based broadcast. |

### Next.js / SCM web

| Piece | Notes |
|-------|-------|
| Firebase Admin SDK init | Shared instance used by both directions |
| `POST /api/mobile/register-fcm-token` | Receives registration from Directus Flow or Spring Boot bridge; stores in `driver_push_tokens` |
| `POST /api/web/register-fcm-token` | Called from dispatcher browser after login + web push subscribe; stores in `dispatcher_push_tokens` |
| `POST /api/web/unregister-fcm-token` | Called on dispatcher logout; deletes the web token |
| DP-approval send handler | Option A: inline in approval action → Admin SDK. Option B: Webhook receiver endpoint |
| Driver-event webhook receiver | Receives Directus Flow → resolves dispatcher → Admin SDK send |
| `firebase-messaging-sw.js` | Service worker for receiving web pushes |
| VAPID key config | Required by FCM Web SDK; same Firebase project |
| Cron (~daily) | Sweep `last_seen` >30d (driver) / >7d (dispatcher) tokens |

### Flutter

Only minor additions:
- Ensure `NotificationService._handleTapPayload`/`_navigateWithData` also triggers `fetchActiveTrip()` for the new push `type` values. The deep-link infrastructure already exists.
- No new HTTP calls, no new models, no new services.

### Spring Boot

Add DELETE endpoint for unregister-fcm-token if mobile registration stays on Spring Boot (called when app detects unregistered response). Alternatively, move mobile registration to Directus for consistency.

### Nothing changes in

Operational collections (`post_dispatch_plan`, `post_dispatch_invoices`, `fleet_emergency_reports`, etc.) — push is a side effect, not embedded in their schema. Firebase project config — reuse the existing Firebase project already wired in `main.dart`.
