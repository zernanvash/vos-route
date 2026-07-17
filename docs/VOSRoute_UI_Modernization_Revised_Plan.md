# VOSRoute UI Modernization — Revised Implementation Plan

Revises `new_ui_implementation_plan.md`. Same visual scope and target design system (Google Stitch — Corporate Modern & Glassmorphic). Changes from the original: explicit logic-preservation boundary for high-risk screens, phased commits instead of one mega-diff, light-mode tokens specified, expanded verification, and a contrast check added.

**Unchanged from original**: no functionality, business logic, background services, network handling, or data synchronization rules are modified. This revision makes that boundary concrete and enforceable per-file rather than a general statement.

---

## Global Rule — Logic Preservation Boundary

For **every** file touched in this plan, only the following may change:
- Widget tree structure (layout, nesting, spacing widgets)
- Style properties (colors, fonts, radii, borders, elevation, padding/margin values)
- Static text/label strings that are purely presentational (not data-bound)

The following must remain **byte-identical** — no reformatting, no "cleanup," no restructuring, even incidentally:
- Any `onPressed`/`onTap`/`onChanged` callback body
- Any call into a provider, repository, or service method
- Any state variable, its type, or its initialization
- Any conditional logic that gates an action (e.g. button-enabled checks, validation)

**Screens requiring extra care** (each sits directly on logic touched or flagged elsewhere in this project — restyle the presentation only, do not touch the call beneath it):
- `stops_list_screen.dart` — `_showOtherStopStatusDialog` calls `updateOtherStopStatus()`. Restyle the dialog's appearance only; the value passed to that call must not change.
- `sos_screen.dart` — sits next to the still-open "SOS needs a confirmation dialog" gap (QA finding #11). A styling pass on the dropdown must not add, remove, or alter the confirmation flow — that's a separate, not-yet-scheduled fix.
- `quest_screen.dart` — adjacent to the orphaned-photo-row / upload-ordering issue already tracked in `AGENTS.md` §2.7 item 5. Restyle the capture-preview grid only; do not touch the capture → queue → upload pipeline.

If restyling any of these three screens turns out to require touching a callback or state variable to achieve the visual result, stop and flag it rather than proceeding — that's a sign the "style-only" boundary can't be cleanly held for that widget, and it needs a design alternative, not a logic change smuggled in under a UI pass.

---

## Component 1: Theme & Foundations

#### [MODIFY] `lib/theme/app_colors.dart`

**Dark theme:**
- Brand Primary Blue: `#3B6EF0`
- Deep Background: `#080810`
- Tonal Card Background: `#0F0F1A`
- Secondary Surface/Hover state: `#1A1A22`
- Thin Outline Borders: `#1F1F27`
- Success/Posted: `#22C55E` · Error/SOS: `#EF4444` · Warning/Inbound: `#F97316` · Info/Dispatch: `#3B82F6`

**Light theme — specify before implementation, do not leave implicit:**
- Confirm whether light-mode tokens already exist elsewhere in the design system doc (`Design_System.md`/`Design_System_theme.json`) and need only parity-checking against this dark set, or whether they need to be derived fresh.
- If deriving fresh: propose a light equivalent for each dark token above (background, card, surface, border, and the four status colors — status colors likely stay the same or get slightly adjusted for contrast on a light background, not the background/surface/border set which need actual light equivalents).
- Do not proceed to Component 3 (screens) until light-mode tokens are confirmed — screens will be styled against both, and re-deriving light tokens after 15 screens are already restyled is wasted rework.

#### [MODIFY] `lib/theme/app_spacing.dart`
- Grid: `xxs: 4`, `xs: 8`, `sm: 12`, `md: 16`, `lg: 24`, `xl: 32`
- Radius: `cardRadius: 12`, `smallRadius: 8`, `badgeRadius: 20` (pill badges)

#### [MODIFY] `lib/theme/app_typography.dart`
- Headings (`display-lg`, `title-md`) → **Plus Jakarta Sans**, `-0.02em` letter-spacing on display.
- Body (`body-md`) → **Inter**.
- Labels/metadata (`label-sm`) → **Manrope**, `0.05em` letter-spacing.
- Text color: `#FAFAFA` primary, `#ADADB8` secondary/muted — confirm light-mode equivalents alongside the color-token work above.
- **Font binaries**: if `.ttf`/`.otf` files for these three families aren't already in `pubspec.yaml`, flag this explicitly rather than silently falling back to Flutter's default rendering — a silent fallback means the "modernization" doesn't actually show up, which defeats the purpose of this pass.

#### [MODIFY] `lib/theme/app_theme.dart`
- Bind updated colors, spacing, fonts globally.
- Style default `CardThemeData`, `DialogThemeData`, `InputDecorationTheme`, `ElevatedButtonThemeData`, `OutlinedButtonThemeData` — 12px rounded corners, correct borders per theme mode.

**Commit boundary**: Component 1 is its own commit. Verify `flutter analyze` + `dart format lib/` clean, and confirm the app still builds and launches (theme changes alone can break builds if a referenced token is renamed and a downstream file wasn't updated) before proceeding to Component 2.

---

## Component 2: Reusable Widgets

#### [MODIFY] `lib/widgets/status_chip.dart`
- Background: 12% opacity of status color. Border: 20% opacity of status color. Shape: fully rounded (pill). Solid dot indicator + text.
- **Contrast check**: verify chip text remains legible at 12%-opacity backgrounds against both the dark (`#080810`) and light background — a light-opacity chip background under body text can fail contrast depending on what's actually rendered underneath it (cards vs. bare screen background). Check this specifically before treating the token values as final, not just visually eyeball once and move on.

#### [MODIFY] `lib/widgets/stop_card.dart`
- `#0F0F1A` background (dark), thin `#1F1F27` outline, updated padding via `AppSpacing`.

#### [MODIFY] `lib/widgets/photo_capture_sheet.dart`
- Replace hardcoded `Colors.grey.shade900` with `Theme.of(context).colorScheme.surface`.
- `RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16)))`.
- Buttons restyled to `cs.primaryContainer`/secondary backgrounds.
- **Logic boundary applies**: this sheet is part of the photo capture flow — restyle the container/buttons only, the capture and upload-trigger logic underneath must not change (see Global Rule above, this file is adjacent to the flagged `quest_screen.dart` risk area).

#### [MODIFY] `lib/widgets/signature_pad.dart`
- Glassmorphic container: `#0F0F1A` fill, 1px `#1F1F27` border, 12px radius.

**Commit boundary**: Component 2 is its own commit, verified independently before Component 3 begins.

---

## Component 3: Operational & Utility Screens — Phased, Not One Diff

Split into three batches, each its own commit, each independently verified (build + manual check on both themes) before starting the next batch.

### Batch 3a — Core driver flow (highest traffic, verify first)
- `login_screen.dart`
- `home_screen.dart` (header/glassmorphism, performance chart tidy, `_previousPlansList` cards, `_PerformanceModal` bottom sheet)
- `dispatch_plans_screen.dart`

### Batch 3b — Stop/invoice/photo flow (contains the flagged high-risk screens — apply Global Rule strictly)
- `stops_list_screen.dart` — **apply logic boundary, see above**
- `stop_detail_screen.dart`
- `invoices_screen.dart`
- `invoice_detail_screen.dart`
- `quest_screen.dart` — **apply logic boundary, see above**
- `trip_photos_screen.dart`

### Batch 3c — Utility/secondary screens
- `sos_screen.dart` — **apply logic boundary, see above**
- `budget_screen.dart`
- `settings_screen.dart`
- `sync_log_screen.dart`
- `history_screen.dart`

---

## Verification Plan (expanded)

### Automated
- `flutter analyze` — zero errors/warnings introduced, per commit batch (not just at the end).
- `dart format lib/` — clean, per commit batch.

### Manual — per batch, per theme mode
- Build and run on device/emulator.
- **Screenshot each modified screen in both Dark and Light mode** — this is the actual verification artifact, not just an in-the-moment visual check. Compare against the token values above (spot-check a few hex values with a color picker on the screenshots if there's any doubt a token was applied correctly).
- For the three flagged high-risk screens specifically: after restyling, re-run the relevant functional check (mark an invoice's "other stop" status and confirm it still reaches `updateOtherStopStatus()` correctly; trigger SOS and confirm the existing flow — confirmation dialog or not — is unchanged; capture a quest photo and confirm it still queues normally) — a visual pass on these three needs a functional smoke-check alongside it, not just "does it look right."

### Sign-off
Do not proceed to the next batch until the current batch's automated + manual verification is confirmed with actual evidence (screenshots, analyze output) — consistent with this project's general standard of evidence over description.
