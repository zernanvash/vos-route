# VOSRoute Trip Photo Audit — 2026-07-14

This is a read-only audit of the live Directus `post_dispatch_trip_photos`
collection. No backend records were created, updated, or deleted.

## Evidence

The audit requested all rows with:

`GET /items/post_dispatch_trip_photos?limit=-1&fields=id,directus_uuid,uploaded_at`

Each non-empty `directus_uuid` was then checked read-only with:

`GET /files/{directus_uuid}?fields=id`

The requests used the existing VOSRoute static Directus token.

## Results

| Measure | Count |
|---|---:|
| Total trip-photo rows | 29 |
| Rows missing `directus_uuid` | 21 |
| Rows missing `uploaded_at` | 29 |
| Populated UUIDs that did not resolve to a Directus file | 0 |

The eight rows with populated UUIDs all resolved to a Directus file. These
counts are point-in-time evidence from 2026-07-14. Cleanup is explicitly out of
scope and requires a separately approved backup, dry run, and mutation plan.
