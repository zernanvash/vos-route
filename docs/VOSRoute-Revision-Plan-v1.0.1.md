# VOSRoute Revision Plan v1.0.1

> **Status**: Approved. Implements 4-phase architecture revision: Action Queue → Photo Quest → UI Design System → Other Stops (deferred).
> Decisions locked from alignment session (see §H).

---

## Table of Contents

- [A. Action Queue Architecture (PERFORMANCE)](#a-action-queue-architecture-performance)
- [B. Invoice Photo Quest (INVOICE PROOF & POD)](#b-invoice-photo-quest-invoice-proof--pod)
- [C. UI Design System (UIFIX)](#c-ui-design-system-uifix)
- [D. Directus Backend Touchpoints](#d-directus-backend-touchpoints)
- [E. File Manifest](#e-file-manifest)
- [F. Execution Order & Dependencies](#f-execution-order--dependencies)
- [G. Verification](#g-verification)
- [H. Locked Decisions](#h-locked-decisions)

---

## A. Action Queue Architecture (PERFORMANCE)

### Problem

Current architecture mixes two patterns — direct HTTP calls (`TripProvider.confirmDeparture` PATCHes Directus live) AND SQLite queue-based sync (`SyncService` flushes `gps_queue`, `pod_queue`, etc.). This creates:

1. Race conditions (local cache vs server state)
2. Two-way sync where user only wants one-way (server→app data, queue→server actions)
3. Unnecessary `cached_trips` SQLite table persisting operational data

### Solution: Single Action Queue Table

Replace all 5 queue tables (`gps_queue`, `pod_queue`, `trip_photo_queue`, `emergency_queue`, `ad_hoc_stop_queue`) + `cached_trips` with a single `action_queue` table.

#### Schema (`lib/db/database.dart` — migration v2→v3)

```sql
CREATE TABLE action_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  action_type TEXT NOT NULL,
  action_payload TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  http_method TEXT NOT NULL,
  batch_group TEXT,
  batch_priority INTEGER DEFAULT 0,
  status TEXT DEFAULT 'pending',
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 5,
  created_at TEXT,
  last_attempt TEXT
);
```

**Remove tables**: `gps_queue`, `pod_queue`, `trip_photo_queue`, `emergency_queue`, `ad_hoc_stop_queue`, `cached_trips`.

#### Action Types

| `action_type` | `http_method` | `endpoint` | `batch_group` | Priority |
|---|---|---|---|---|
| `confirm_departure` | PATCH | `/items/post_dispatch_plan/{id}` | null | 1 (urgent) |
| `mark_arrived` | PATCH | `/items/post_dispatch_plan/{id}` | null | 1 |
| `update_stop_status` | PATCH | `/items/post_dispatch_invoices/{id}` | null | 1 |
| `link_pod_photo` | POST | `/items/post_dispatch_nte` | null | 2 |
| `link_trip_photo` | POST | `/items/post_dispatch_trip_photos` | null | 2 |
| `submit_sos` | POST | `/items/fleet_emergency_reports` | null | 1 |
| `gps_batch` | POST | `/items/post_dispatch_gps_logs` | `gps:{tripId}` | 3 |
| `update_invoices_departure` | PATCH | `/items/sales_invoice` | null | 1 |
| `update_orders_departure` | PATCH | `/items/sales_order` | null | 1 |

#### New/Modified Services

**New: `ActionQueueService`** — replaces `SyncService`
- `enqueue(ActionEntry)` — inserts into SQLite, triggers `processQueue()`
- `processQueue()` — processes items in priority order (1→2→3), status `pending→in_flight→completed`
- Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s cap (resets on connectivity change)
- Batched GPS: `_flushGpsBatch()` runs every 5 points or 60s

**Modified: `TripProvider`**
- `confirmDeparture()`: optimistically updates in-memory state → enqueues `confirm_departure` + `update_invoices_departure` + `update_orders_departure` actions → calls `processQueue()`. No Directus PATCH, no SQLite cache write.
- `markArrivedAtBase()`: same pattern.
- `updateStopStatus()`: same pattern.
- `fetchActiveTrip()`: still hits Directus directly (one-way server→app). In-memory `Map<int, CachedTrip>` as fallback, no SQLite.
- Remove: `TripDao` references, `_loadFromCache()`, `cached_trips` writes throughout.

**Modified: `EmergencyService`**
- `submitReport()`: enqueues `submit_sos` action instead of `queueDao.insertEmergency()` + direct POST.

**Modified: `GpsService`**
- Write GPS points into `action_queue` with `batch_group: 'gps:trip_42'`. Accumulates 5 points then flushes.

**Modified: `UploadService`**
- Directus `/files` upload stays synchronous (must get UUID).
- The LINK step (creating `post_dispatch_nte` / `post_dispatch_trip_photos` record) goes through action queue.

**Removed files**:
- `lib/db/queue_dao.dart`
- `lib/db/trip_dao.dart`
- `lib/services/sync_service.dart`
- `lib/providers/sync_provider.dart`
- `lib/widgets/sync_indicator.dart`

**New files**:
- `lib/services/action_queue_service.dart`
- `lib/providers/action_queue_provider.dart`
- `lib/models/action_entry.dart`

---

## B. Invoice Photo Quest (INVOICE PROOF & POD)

### Problem

Currently, POD photo capture is manual per-stop in `StopDetailScreen`. Driver can skip it, no enforcement, no progress visibility. Invoice photos are not tied to invoice_id.

### Solution: Quest-Driven Mandatory Photo Flow

#### New Model (`lib/models/photo_quest.dart`)

```dart
class PhotoQuestItem {
  final int invoiceStopId;
  final int invoiceId;
  final String invoiceNo;
  final String customerName;
  final double? amount;
  bool photoCaptured;
  String? localPhotoPath;
  String? directusFileUuid;
  bool signatureCaptured;
  String? stopStatus;
}

class PhotoQuest {
  final int tripId;
  final List<PhotoQuestItem> items;
  bool get allComplete => items.every((i) => i.photoCaptured);
  int get completedCount => items.where((i) => i.photoCaptured).length;
  int get totalCount => items.length;
}
```

#### Flow

1. **On `confirmDeparture()`**: `TripProvider` builds `PhotoQuest` from all `InvoiceStop`s. Stores in-memory on provider.

2. **New `QuestScreen`** (`lib/screens/quest_screen.dart`):
   - Shows each invoice as a quest card with progress indicators:
     - 📷 Photo — checkmark or pending
     - ✍️ Signature — checkmark or pending
     - ✅ Status — checkmark or pending
   - Progress bar across top: `X / Y complete`
   - "Continue Quest" button starts the camera sequence
   - Replaces the old "Stops" tab as the primary driver interface

3. **Auto-sequence camera** (mandatory, no skip):
   - App opens camera directly via `ImagePicker` (source: camera only, no gallery)
   - Driver captures photo → preview shown with "Accept / Retake"
   - On accept: upload to Directus `/files` → queue `link_pod_photo` action
   - Auto-advance to next incomplete invoice
   - Sequence continues until ALL invoices have photos captured

4. **Signature + status**:
   - After all photos done, show signature pad for current stop
   - Then show 4 status buttons (Fulfilled, Not Fulfilled, etc.)
   - Then advance to next stop

5. **Arrival gate integration**:
   - `markArrivedAtBase()` checks `quest.allComplete`
   - If incomplete: show blocking dialog "Complete photo quest for all invoices first" with list of pending items
   - User CANNOT mark arrived until quest is complete

6. **`StopDetailScreen` changes**:
   - Remove manual photo capture section (photo is done in quest flow)
   - Keep: info section, signature section, status section (as review)
   - Signature already captured in quest flow, can be re-done here

---

## C. UI Design System (UIFIX)

### Problem

~4000 lines of repetitive markup — every card inlines `Colors.grey.shade900`, `borderRadius: 12`, `padding: EdgeInsets.all(16)`, etc. No responsive layout (hardcoded sizes, no `LayoutBuilder`). No theme tokens.

### Solution: `lib/theme/` + `lib/core/`

#### Theme Tokens (`lib/theme/`)

| File | Contents |
|---|---|
| `app_colors.dart` | `AppColors` class with static color tokens: `surface`, `surfaceVariant`, `primaryGradientStart`, `primaryGradientEnd`, `textPrimary`, `textSecondary`, `border`, etc. |
| `app_typography.dart` | `AppTextStyle` with presets: `heading`, `subheading`, `body`, `caption`, `label`. |
| `app_spacing.dart` | `Insets.xs` (4), `Insets.sm` (8), `Insets.md` (12), `Insets.lg` (16), `Insets.xl` (24), `Insets.xxl` (32). |
| `app_theme.dart` | `ThemeExtension<AppColors>` implementation, single `ThemeData` factory using all tokens above. |

#### Reusable Widgets (`lib/core/`)

| Widget | Replaces |
|---|---|
| `AppCard` | All inline `Card(color: Colors.grey.shade900, shape: ...)` with configurable gradient, border, padding |
| `AppListTile` | `ListTile` with dark defaults (white text, grey subtitle) |
| `AppSectionHeader` | "Performance", "Dispatch Queue", "Stop Progress" heading pattern |
| `AppProgressBar` | `LinearProgressIndicator` with dark background + green fill |
| `AppStatusBadge` | All inline `Container(... padding ... border radius ... status text)` blocks |
| `AppActionButton` | All `ElevatedButton` with 52px height, icon, consistent styling |
| `AppDialog` | Unified `_showActionDialog` (title, body, remarks field, cancel/confirm) |
| `AppInput` | Styled `TextField` + `DropdownButtonFormField` with dark fill |
| `AppGradientHeader` | The blue gradient header card used in `dispatch_plans_screen.dart` and `home_screen.dart` |

#### Responsive Layout Changes

- `StopsMapScreen` bottom sheet: `LayoutBuilder` → expanded panel on >600dp width (tablet), draggable sheet on phone
- `StopDetailScreen`: Replace `SingleChildScrollView` with proper `Column` + `Expanded` + scrollable section
- All hardcoded padding values → `Insets.*` constants
- Remove `const SizedBox(height: ...)` in favor of `Insets.*` with `SizedBox` helper or `Padding`

#### Navigation

- New `lib/core/app_routes.dart`: static string constants (`static const stopDetail = '/stop-detail'`)
- Route generation centralized in `lib/core/route_config.dart`

---

## D. Directus Backend Touchpoints

> Per AGENTS.md: Do NOT create or alter Directus collections/columns unless listed here. The following are approved.

| Collection | Change | Reason |
|---|---|---|
| `post_dispatch_plan` | No change | Existing fields suffice |
| `sales_invoice` | No change | Existing `transaction_status`, `isDispatched`, `dispatch_date` used by bulk PATCH |
| `sales_order` | No change | Existing `order_status` used |
| `post_dispatch_invoices` | No change | Existing `status`, `invoiceAt`, `remarks` used |
| `post_dispatch_gps_logs` | No change | Existing schema used by batched POST |
| `post_dispatch_nte` | No change | Existing schema used for POD linking |
| `post_dispatch_trip_photos` | No change | Existing schema used |
| `fleet_emergency_reports` | No change | Existing schema used |
| **`post_dispatch_plan_others`** | Add `latitude`, `longitude` (decimal 10,7) | Required for map plotting (deferred to separate revision) |

---

## E. File Manifest

### New Files

| File | Phase |
|---|---|
| `lib/models/action_entry.dart` | 1 — Action Queue |
| `lib/services/action_queue_service.dart` | 1 |
| `lib/providers/action_queue_provider.dart` | 1 |
| `lib/models/photo_quest.dart` | 2 — Photo Quest |
| `lib/screens/quest_screen.dart` | 2 |
| `lib/theme/app_colors.dart` | 3 — UI System |
| `lib/theme/app_typography.dart` | 3 |
| `lib/theme/app_spacing.dart` | 3 |
| `lib/theme/app_theme.dart` | 3 |
| `lib/core/app_card.dart` | 3 |
| `lib/core/app_list_tile.dart` | 3 |
| `lib/core/app_section_header.dart` | 3 |
| `lib/core/app_progress_bar.dart` | 3 |
| `lib/core/app_status_badge.dart` | 3 |
| `lib/core/app_action_button.dart` | 3 |
| `lib/core/app_dialog.dart` | 3 |
| `lib/core/app_input.dart` | 3 |
| `lib/core/app_gradient_header.dart` | 3 |
| `lib/core/app_routes.dart` | 3 |
| `lib/core/route_config.dart` | 3 |

### Modified Files

| File | Phase | Changes |
|---|---|---|
| `lib/db/database.dart` | 1 | Migration v2→v3: drop old tables, create `action_queue` |
| `lib/services/api_service.dart` | 1 | Add `batchPatchDirectus()` for batched GPS |
| `lib/services/upload_service.dart` | 1 | Return UUID, don't link |
| `lib/services/gps_service.dart` | 1 | Write to `action_queue` instead of `gps_queue` |
| `lib/services/emergency_service.dart` | 1 | Use `ActionQueueService.enqueue()` |
| `lib/providers/trip_provider.dart` | 1, 2 | Action queue integration, quest initialization, arrival gate |
| `lib/providers/gps_provider.dart` | 1 | Use `ActionQueueProvider` |
| `lib/main.dart` | 1, 3 | Replace `SyncProvider` → `ActionQueueProvider`, new theme |
| `lib/screens/stop_detail_screen.dart` | 2, 3 | Remove manual photo, extract to quest, apply design system |
| `lib/screens/dispatch_plans_screen.dart` | 3 | Refactor to design system |
| `lib/screens/home_screen.dart` | 3 | Refactor to design system |
| `lib/screens/stops_map_screen.dart` | 3 | Refactor to design system |
| `lib/screens/budget_screen.dart` | 3 | Refactor to design system |
| `lib/screens/settings_screen.dart` | 3 | Refactor to design system |
| `lib/screens/sos_screen.dart` | 3 | Refactor to design system |
| `lib/screens/history_screen.dart` | 3 | Refactor to design system |
| `lib/widgets/stop_card.dart` | 3 | Refactor to design system |
| `lib/widgets/status_chip.dart` | 3 | Refactor to design system |
| `lib/widgets/photo_capture_sheet.dart` | 3 | Refactor to design system |
| `lib/widgets/signature_pad.dart` | 3 | Refactor to design system |
| `lib/providers/auth_provider.dart` | 3 | Minor: use theme tokens |

### Removed Files

| File | Reason |
|---|---|
| `lib/db/queue_dao.dart` | Replaced by `ActionQueueService` |
| `lib/db/trip_dao.dart` | No more cached trips in SQLite |
| `lib/services/sync_service.dart` | Replaced by `ActionQueueService` |
| `lib/providers/sync_provider.dart` | Replaced by `ActionQueueProvider` |
| `lib/widgets/sync_indicator.dart` | No longer needed |

---

## F. Execution Order & Dependencies

```
Phase 1 (Action Queue)
  ├── No dependencies
  ├── lib/models/action_entry.dart
  ├── lib/db/database.dart (migration)
  ├── lib/services/action_queue_service.dart
  ├── lib/providers/action_queue_provider.dart
  ├── Modify: api_service.dart, upload_service.dart, gps_service.dart,
  │           emergency_service.dart, trip_provider.dart, gps_provider.dart, main.dart
  └── Remove: queue_dao.dart, trip_dao.dart, sync_service.dart, sync_provider.dart, sync_indicator.dart

Phase 2 (Photo Quest) ── depends on Phase 1
  ├── lib/models/photo_quest.dart
  ├── lib/screens/quest_screen.dart
  └── Modify: trip_provider.dart, stop_detail_screen.dart

Phase 3 (UI Design System) ── no dependency on Phase 1/2 (can parallelize)
  ├── lib/theme/* (6 files)
  ├── lib/core/* (11 files)
  └── Refactor all screens + widgets (16 files)

Phase 4 (Other Stops) ── deferred
```

**Recommended**: Run Phase 1 + Phase 3 in parallel (different file sets). Phase 2 after Phase 1.

---

## G. Verification

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
dart format lib/ --set-exit-if-changed
```

### Manual Test Scenarios

| # | Scenario | Expected |
|---|---|---|
| 1 | Depart with no network | Action queued locally. On reconnect, action processed (PATCH to Directus). |
| 2 | Arrive at base with incomplete quest | Blocking dialog: "Complete photo quest for all invoices first". |
| 3 | 5 invoices in trip | Camera auto-opens 5 times. Each photo uploaded + linked. No skip. |
| 4 | SOS submitted offline | Action queued. Processed on reconnect. |
| 5 | GPS tracking with no network | Points accumulate in action_queue with batch_group. Flushed when online. |
| 6 | Pull-to-refresh active trip | One-way fetch from Directus. In-memory cache used if offline. |
| 7 | Theme consistency check | All cards use `AppCard`, all buttons use `AppActionButton`, all status badges use `AppStatusBadge`. No inline color constants remain. |

---

## H. Locked Decisions (from alignment)

| # | Question | Decision |
|---|---|---|
| 1 | Action queue retry strategy | Exponential backoff: 1s → 2s → 4s → 8s → 16s → 30s cap |
| 2 | Photo quest capture flow | Auto-sequence, mandatory, NO skip |
| 3 | Other stops upgrade scope | Deferred to separate revision. Focus on customer/invoice stops. |
| 4 | UI architecture | Full design system (theme tokens) + reusable widgets |
| 5 | Arrived-at-base gate | Blocks if any invoice quest item is incomplete |
| 6 | Signature requirement | All status submissions require signature |
| 7 | Data direction | One-way sync: server→app for data. Action queue for outgoing writes. |
| 8 | GPS batching | 5-point batches OR 60s timer, whichever comes first |
