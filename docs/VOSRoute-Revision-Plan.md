# VOSRoute Revision Plan

> Status: Planned, pending execution. Locked decisions from alignment session.

## A. DASHBOARD — `home_screen.dart`, `trip_provider.dart`

### Overall status indicator from previous DPs
- New `TripProvider.fetchPreviousDispatchOverallStatus()`: `GET /items/post_dispatch_plan` filtered by `driver_id`, `filter[status][_in]=For Clearance,Posted`, `sort=-date_encoded`, `limit=20`.
- Compute a single overall status (no slices) from the driver's previous dispatch plans — minimal v1 gauge/donut/chip aggregating clearance/fulfillment ratio. Flagged as v1 interpretation; refine in review.
- Render compact card on `HomeScreen` above the active trip header.

### Current trips list
- Render the driver's active + recent dispatch plans as cards (doc_no, status, vehicle plate, date). Reuse the new previous-dispatch query + active trip. Tap → existing trip dashboard.

## B. STOPS — `stops_screen.dart`, `stop.dart`, new stop-grouping helper

- Group `TripProvider.invoiceStops` by `customerCode` → `List<StopGroup { customerCode, List<InvoiceStop> }>`.
- Render as collapsible headers (`ExpansionTile`). Header trailing indicator:
  - All Fulfilled → green ✓
  - All Not Fulfilled → red + count
  - Mixed → yellow + count of non-fulfilled
- Expanded body: customer's invoices, each row = invoice no + `StatusChip` + inline quick-status action.
- Minimize status change action: inline quick-status bottom sheet (4 status buttons) from the expanded invoice row; no navigation to `StopDetailScreen` just to change status. POD photo/signature flow stays in `StopDetailScreen`.

## C. MAP — `pubspec.yaml`, `map_screen.dart`, `stop.dart`, `trip_provider.dart`

- Replace `flutter_map` (and `latlong2` if unused elsewhere) with `maplibre_gl` in `pubspec.yaml`. Rewrite `MapScreen` around `MaplibreMap`/`MaplibreMapController`.
- Customer (invoice) stops: extend `TripProvider` invoices Directus query to nest `invoice_id.customer_id.latitude,longitude,customer_name,address` (verify exact relation field — `customer_id` vs `customer_code` — against live Directus before coding). Add `latitude`/`longitude` to `InvoiceStop` model.
- Other stops from `post_dispatch_plan_others`: add `latitude`/`longitude` columns to the Directus collection (coordinator enters coords when creating ad-hoc stops). Update `OtherStop` model + TripProvider fetch + local DAO cache payload.
- Draw driver current location from `GpsProvider.lastPosition`; center map on driver; (optional) polyline through stops.

## D. REVISIONS (cross-cutting)

### `TripProvider.markArrivedAtBase` gate
- If any `_invoiceStops` entry has status `Pending` or `In Progress`, set `_error` and skip the PATCH.
- Surface the block in the HomeScreen arrival dialog (list which stops remain open).

### Required customer signature (all status submissions)
- Wire `SignaturePad.onSign` to retain `Uint8List` in `StopDetailScreen` state.
- In `_updateStatus`: block if signature bytes are null; upload signature PNG to Directus `POST /files` via `UploadService`, store UUID, link via `post_dispatch_nte` (same flow as POD photo), then proceed with the status PATCH.
- Applies to inline quick-status path too (quick-status sheet must require signature before confirming).

### Budget per dispatch plan header
- Rework `budget_screen.dart` to fetch the driver's dispatch plans (active + recent) and render each DP as a header card (doc_no + status + vehicle plate) with its `post_dispatch_budgeting` lines + subtotals beneath.
- Reuse the parallel Directus fetch pattern from `TripProvider`.

## E. Schema / backend touchpoints (Directus admin action required)

> Per AGENTS.md: do NOT create Directus tables or columns unless explicitly instructed. The following require explicit user approval before implementation:

- Add `latitude` (decimal 10,7) and `longitude` (decimal 10,7) to `post_dispatch_plan_others` in Directus. Coordinator enters coords when creating ad-hoc stops.
- `customer` collection already has lat/lng per user confirmation (no change needed).

## F. Files to create / edit

| File | Action |
|---|---|
| `pubspec.yaml` | swap flutter_map/latlong2 → maplibre_gl |
| `lib/models/stop.dart` | add lat/lng to `InvoiceStop` + `OtherStop`; add `StopGroup` helper |
| `lib/providers/trip_provider.dart` | nest customer coords in invoices query; fetch `plan_others` coords; add `markArrivedAtBase` gate; add previous-dispatch + active-trips queries |
| `lib/screens/home_screen.dart` | overall-status indicator card + current-trips list |
| `lib/screens/stops_screen.dart` | group by customer; `ExpansionTile` headers + aggregate indicators; inline quick-status sheet |
| `lib/screens/map_screen.dart` | rewrite for maplibre_gl; plot customer + other stops + driver |
| `lib/screens/stop_detail_screen.dart` | required signature: retain bytes, block on null, upload + link via NTE |
| `lib/screens/budget_screen.dart` | per-DP headers with budget lines + subtotals |
| `lib/widgets/signature_pad.dart` | (minor) ensure `onSign` reflects nullability cleanly |

## G. Verification (no test runner)

```bash
flutter analyze
dart format lib/
```

Manual: login → active trip loads → overall-status card shows → expand customer header → quick-status sheet requires signature before submitting → arrived-at-base blocked while invoices pending → map shows customer + other + driver markers via maplibre_gl.

## H. Locked decisions (from alignment)

| # | Question | Decision |
|---|---|---|
| 1 | Stop coordinates source | Use `customer` collection lat/lng for invoice stops; add lat/lng to `post_dispatch_plan_others` for other stops |
| 2 | Map SDK | Replace flutter_map with maplibre_gl |
| 3 | Dashboard pie scope | Overall status from previous DPs (no slices) |
| 4 | Signature requirement | All status submissions |
| 5 | Arrived-base gate | Invoice stops only |
| 6 | Customer grouping key | `customer_code` |
| 7 | Budget revision | Show budget per dispatch plan headers |
