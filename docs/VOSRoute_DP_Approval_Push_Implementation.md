# DP Approval Push — Implementation Guide

**Scope:** When a dispatcher approves a dispatch plan in the Next.js/SCM web app, the assigned driver receives an FCM push notification within seconds. The push is a wake-up signal only — the app reconciles from Directus on receipt.

---

## 1. Directus — Schema Additions

Approval required from backend owner before creating these collections/fields.

### 1.1 `driver_push_tokens`

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid (PK) | auto-generated |
| `user_id` | m2o → `directus_users` | the driver. Indexed. |
| `fcm_token` | string | device token from Firebase, unique |
| `device_info` | string | `"Android"` or `"iOS"` |
| `created_at` | timestamp (auto) | |
| `last_seen` | timestamp | updated on every successful send |

**Permissions:** The static token's role needs Create/Read for drivers to register their tokens, and Read for the Next.js server to look up tokens. The mobile registration endpoint (Spring Boot or Directus) writes as the driver user; the Next.js send handler reads via the static token.

### 1.2 Index on `fcm_token`

A unique index on `driver_push_tokens.fcm_token` prevents duplicate rows when the same token is re-registered.

---

## 2. Flutter — FCM Token Registration

### 2.1 What already exists

`NotificationService.init()` in `lib/services/notification_service.dart`:
- Calls `FirebaseMessaging.instance.getToken()` on startup
- Registers via `POST /api/dispatch/mobile/register-device` with payload `{ fcmToken, deviceInfo }`
- Listens on `FirebaseMessaging.onTokenRefresh.listen(...)` for silent rotations and re-registers

### 2.2 Changes needed (small)

None to the registration flow — it already fires on startup and on token refresh.

**Add handling for the new push type.** In `_navigateWithData` (same file), add a branch for the new push type that calls `TripProvider.fetchActiveTrip(forceRefresh: true)`:

```dart
// Inside _navigateWithData switch or a new dedicated handler
if (data['type'] == 'dp_approved' || data['type'] == 'dp_dispatched') {
  // Fetching will show a local notification if a new trip is found
  // (the existing TripProvider._lastNotifiedTripId gate prevents duplicates)
  // The push itself was already shown as a local notification by onMessage/onBackgroundMessage.
  // This branch handles the tap action — navigate to the active trip.
  nav.pushNamed('/home');
  return;
}
```

The existing `onMessage` foreground handler and `vosRouteBackgroundHandler` already display the notification body. The tap handler is where you direct the driver to the active trip screen.

---

## 3. Flutter — Direct Token Registration (No Spring Boot)

The current `NotificationService._registerToken()` posts to Spring Boot. Replace that with a direct write to Directus `driver_push_tokens` using the static token. The Flutter app already has the driver's `user_id` from `AuthProvider.profile.userId` (fetched via Directus `/items/user`).

In `lib/services/notification_service.dart`, change `_registerToken`:

```dart
Future<void> _registerToken(String token) async {
  try {
    final profile = AuthService().profile; // or via provider
    if (profile == null) return;
    await _api.postDirectus('/items/driver_push_tokens', data: {
      'user_id': profile.userId,
      'fcm_token': token,
      'device_info': 'Android',
    });
  } catch (e) {
    debugPrint('[NotificationService] token register failed: $e');
  }
}
```

No upsert logic needed — the unique index on `fcm_token` (see §1.2) prevents duplicates. If the token already exists, Directus returns a 409; catch and ignore it.

The existing `onTokenRefresh.listen` continues to call this same method, so silent rotations are handled automatically.

**Also remove** the old Spring Boot call from the same file — the `POST /api/dispatch/mobile/register-device` endpoint is no longer used.

---

## 4. Next.js — Server-Side Send

### 4.1 Firebase Admin SDK setup

In the Next.js server code (a server-only module, never exposed to the client):

```typescript
import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    // Or use a service account JSON file:
    // credential: admin.credential.cert(serviceAccount),
  });
}

const messaging = admin.messaging();
```

The service account must have the `firebase.messaging` permission. Download the JSON from Firebase Console → Project Settings → Service Accounts → Generate new private key.

### 4.2 Approve handler integration

Inside the existing "approve dispatch plan" API route (or server action), after the Directus status update succeeds, add the push send:

```typescript
async function sendPushOnApproval(driverId: number, planId: number, docNo: string) {
  try {
    // 1. Look up driver's FCM tokens from Directus
    const tokensRes = await directus.items('driver_push_tokens').readByQuery({
      filter: { user_id: { _eq: driverId } },
      fields: ['fcm_token', 'id'],
    });
    const tokens: string[] = tokensRes.data?.map((t: any) => t.fcm_token) ?? [];
    if (tokens.length === 0) return;

    // 2. Build the message
    const message: admin.messaging.MulticastMessage = {
      tokens,
      data: {
        type: 'dp_approved',
        planId: String(planId),
        docNo,
        screen: '/stop-detail',
      },
      notification: {
        title: 'New Dispatch Plan',
        body: `DP ${docNo} has been approved. Tap to view.`,
      },
      android: { priority: 'high' },
    };

    // 3. Send
    const response = await messaging.sendEachForMulticast(message);

    // 4. Clean up dead tokens
    if (response.failureCount > 0) {
      response.responses.forEach((resp, idx) => {
        if (!resp.success && 
            (resp.error?.code === 'messaging/registration-token-not-registered' ||
             resp.error?.code === 'messaging/invalid-registration-token')) {
          // Delete the dead token row
          const tokenId = tokensRes.data![idx].id;
          directus.items('driver_push_tokens').deleteOne(tokenId);
          console.warn(`Deleted stale token: ${tokenId}`);
        }
      });
    }
  } catch (err) {
    // Log but never throw — push failure must not block the approval
    console.error('[Push] send failed:', err);
  }
}
```

Call this function **after** the Directus PATCH succeeds, but do not await it if you want the approval response to return to the dispatcher immediately:

```typescript
// Inside the approval route handler:
await directus.patch(`/items/post_dispatch_plan/${planId}`, { status: 'For Dispatch' });

// Fire push asynchronously — do not block the HTTP response
sendPushOnApproval(driverId, planId, docNo).catch(console.error);

return { success: true };
```

### 4.3 Disaster recovery / retry

The push is a wake-up signal only. The reconciler is the truth. Do not retry failed sends at the application layer. The dead-token cleanup in step 4 handles chronic failures. A separate monitoring check (e.g., 3 consecutive all-failed sends → alert) is sufficient.

---

## 5. Flutter — Receiving and Handling the Push

No structural changes are needed. The existing `NotificationService` already handles:

| Scenario | Handler | Already works |
|----------|---------|---------------|
| App in foreground | `FirebaseMessaging.onMessage` → `_handleForegroundMessage` → `showLocalNotification` | Yes |
| App in background | `vosRouteBackgroundHandler` (top-level function) | Yes |
| App killed / cold start | `getInitialMessage()` | Yes |
| User taps notification | `_onNotificationTap` → `_navigateWithData` | Yes |

**Add the tap handler for the new type.** In `_navigateWithData`, add before or after the existing switch:

```dart
final type = data['type'] as String?;
if (type == 'dp_approved' || type == 'dp_dispatched') {
  // Navigate to home — fetchActiveTrip() runs automatically on initState
  nav.pushNamedAndRemoveUntil('/home', (route) => false);
  return;
}
```

That's it. The `HomeScreen.initState` already calls `fetchActiveTrip()` and the existing `_lastNotifiedTripId` gate suppresses duplicate local notifications.

---

## 6. Sequence (Final)

```
Dispatcher (Next.js)                Directus                  Admin SDK           Flutter (driver)
      |                                   |                       |                     |
      |  approve (PATCH status)           |                       |                     |
      |---------------------------------->|                       |                     |
      |                                   |                       |                     |
      |  query driver_push_tokens         |                       |                     |
      |<----------------------------------|                       |                     |
      |                                   |                       |                     |
      |  sendEachForMulticast(tokens)     |                       |                     |
      |---------------------------------------------------------->|                     |
      |                                   |                       |  FCM data message   |
      |                                   |                       |-------------------->|
      |                                   |                       |                     |
      |  inspect BatchResponse            |                       |  fetchActiveTrip()  |
      |  delete NotRegistered tokens      |                       |  (screen shows DP)  |
      |---------------------------------->|                       |                     |
```

---

## 7. Rollout checklist

| # | Task | Owner |
|---|------|-------|
| 1 | Create `driver_push_tokens` collection in Directus | Backend |
| 2 | Assign read/write permissions to the static token's role | Backend |
| 3 | Remove Spring Boot registration call from `NotificationService._registerToken()`; replace with direct POST to Directus `/items/driver_push_tokens` | Mobile |
| 4 | Deploy Flutter build (minor change to `_navigateWithData`) | Mobile |
| 5 | Add Firebase Admin SDK to Next.js + service account config | Web |
| 6 | Add `sendPushOnApproval()` to the DP approval route | Web |
| 7 | Push handles asynchronously after Directus PATCH succeeds | Web |
| 8 | Deploy and test end-to-end with a real device | QA |
