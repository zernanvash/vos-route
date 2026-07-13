# Comprehensive Implementation Plan: VOSRoute UI Modernization

This plan outlines the design adjustments to modernize the entire user interface of the **VOSRoute** driver mobile application. We will strictly adhere to the guidelines and tokens extracted from the **Google Stitch Design System** (`Design_System.md` & `Design_System_theme.json`) to transition the app into a premium, cohesive **Corporate Modern & Glassmorphic** aesthetic. 

No functionality, business logic, background services, network handling, or data synchronization rules will be modified.

---

## User Review Required

> [!IMPORTANT]
> This plan covers all screens in the `VOSRoute/` project to ensure absolute design consistency.
> 
> [!WARNING]
> While we will update the default styling parameters to reflect the typography of **Plus Jakarta Sans** (headings), **Inter** (body), and **Manrope** (labels), the app currently uses the standard Flutter framework text rendering system. If custom local font binaries (`.ttf` or `.otf`) are required, they must be separately added to `pubspec.yaml` by the developer, or we will rely on Flutter fallback rendering.

---

## Proposed Changes

### Component 1: Theme & Foundations

We will align the root design configurations to establish the visual foundation for the entire app.

#### [MODIFY] [app_colors.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/theme/app_colors.dart)
* Standardize dark theme overrides to match the exact Stitch color palette:
  * Brand Primary Blue: `#3B6EF0`
  * Deep Background: `#080810`
  * Tonal Card Background: `#0F0F1A`
  * Secondary Surface/Hover state: `#1A1A22`
  * Thin Outline Borders: `#1F1F27`
* Standardize status colors to match the specific hex codes:
  * Success/Posted: `#22C55E`
  * Error/SOS: `#EF4444`
  * Warning/Inbound: `#F97316`
  * Info/Dispatch: `#3B82F6`

#### [MODIFY] [app_spacing.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/theme/app_spacing.dart)
* Standardize the grid spacing units to follow the systematic 8px-based layout (with 4px micro-spacing):
  * `xxs: 4`, `xs: 8`, `sm: 12`, `md: 16`, `lg: 24`, `xl: 32`
* Update standard corner radius tokens:
  * `cardRadius: 12` (aligning with Stitch `ROUND_TWELVE` rule)
  * `smallRadius: 8`
  * `badgeRadius: 20` (for fully rounded pill badges)

#### [MODIFY] [app_typography.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/theme/app_typography.dart)
* Re-scale all typography styles to map context-aware text tokens to the target Stitch fonts:
  * Headings (`display-lg`, `title-md`) -> Font family **Plus Jakarta Sans** with `-0.02em` letter-spacing on display.
  * Body texts (`body-md`) -> Font family **Inter**.
  * Labels/Metadata (`label-sm`) -> Font family **Manrope** with `0.05em` letter-spacing for readability.
* Adjust color weights so text uses `#FAFAFA` (nearly white, high contrast) for primary info, and `#ADADB8` (muted grey) for secondary captions.

#### [MODIFY] [app_theme.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/theme/app_theme.dart)
* Bind the updated color scheme, spacing units, and font families globally.
* Style the default `CardThemeData`, `DialogThemeData`, `InputDecorationTheme`, `ElevatedButtonThemeData`, and `OutlinedButtonThemeData` to apply 12px rounded corners and correct borders (`#1F1F27` for dark mode) by default.

---

### Component 2: Reusable Widgets

We will adjust the styling of core custom widgets to enforce the glassmorphic card design and status chip specifications.

#### [MODIFY] [status_chip.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/widgets/status_chip.dart)
* Refactor to use the Stitch status chip rule:
  * Background is soft, semi-transparent (e.g. 12% opacity status color).
  * Border is matching translucent outline (e.g. 20% opacity).
  * Shape is fully rounded (pill-shaped, `ROUND_FULL`).
  * Features a solid, vibrant dot indicator alongside the text.

#### [MODIFY] [stop_card.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/widgets/stop_card.dart)
* Ensure stop cards use `#0F0F1A` background, thin `#1F1F27` outline borders, and have proper padding layout (using the updated `Insets`).

#### [MODIFY] [photo_capture_sheet.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/widgets/photo_capture_sheet.dart)
* Modernize the modal capture panel:
  * Remove hardcoded `Colors.grey.shade900` background and use `Theme.of(context).colorScheme.surface`.
  * Set shape to `RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16)))`.
  * Re-style buttons to use `cs.primaryContainer` or secondary backgrounds.

#### [MODIFY] [signature_pad.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/widgets/signature_pad.dart)
* Wrap the canvas in a glassmorphic dashboard container: `#0F0F1A` filled background, 1px `#1F1F27` outline border, and 12px rounded corner shapes.

---

### Component 3: Operational & Utility Screens

We will migrate each screen to the unified Stitch style, using the customized typography, correct backgrounds, and spacing.

#### [MODIFY] [login_screen.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/screens/login_screen.dart)
* Clean up the logo and card layouts. Update the corporate credential input boxes to use the dark-tonal `#0F0F1A` fill and focus outline `#3B6EF0` parameters.

#### [MODIFY] [home_screen.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/screens/home_screen.dart)
* **Header & Performance Section**:
  * Apply glassmorphic headers.
  * Tidy the performance pie chart layout, legend rows, and text alignments.
* **Dispatch Plans List (`_previousPlansList`)**:
  * Ensure the plans cards use the primary theme colors, thin outlines, and status badges.
* **Bottom Sheet (`_PerformanceModal`)**:
  * Style the bottom sheet to have 16px rounded top corners, a clean handle, and unified legends.

#### [MODIFY] [stops_list_screen.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/screens/stops_list_screen.dart)
* Align list headers with `AppSectionHeader` styling.
* Rework `_showOtherStopStatusDialog` to present status options within a styled modal dialog using theme buttons and clear labels.

#### [MODIFY] [stop_detail_screen.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/screens/stop_detail_screen.dart)
* Adjust vertical margins and spacing. Modernize detail item columns (address, sequence, contact details) to use clean Manrope labels and Inter body text.
* Apply modern signature card container borders.

#### [MODIFY] [sos_screen.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/screens/sos_screen.dart)
* Modernize dropdown form fields by adding `dropdownColor` mapping to the theme surface, 12px dropdown popover border radius, and linear expand icons.
* Update warning container layouts to use correct border colors and translucent fills.

#### [MODIFY] [budget_screen.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/screens/budget_screen.dart)
* Style budgeting tables to use tabular font features on numeric values for aligned alignment.
* Ensure list headers use correct typography hierarchy.

#### [MODIFY] [invoices_screen.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/screens/invoices_screen.dart)
* Apply unified card grids, modern search input box focus states, and rounded status badges.

#### [MODIFY] [invoice_detail_screen.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/screens/invoice_detail_screen.dart)
* Update invoice stopping/pricing lists to use crisp lines, correct secondary labels, and padded tables.

#### [MODIFY] [quest_screen.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/screens/quest_screen.dart)
* Modernize grid layouts for camera capture previews. Previews will use rounded corners (12px) and subtle elevations.

#### [MODIFY] [settings_screen.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/screens/settings_screen.dart)
* Update settings card lists and appearance selector rows.
* Style the diagnostic popup loader and result warning alerts to use matching theme overlays.

#### [MODIFY] [sync_log_screen.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/screens/sync_log_screen.dart)
* Modernize log entry cards and clear failed confirmation popups.

#### [MODIFY] [history_screen.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/screens/history_screen.dart)
* Style past trip records to match the home screen's dispatch plan cards.

#### [MODIFY] [trip_photos_screen.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/screens/trip_photos_screen.dart)
* Modernize picture thumbnail grids and capture actions.

#### [MODIFY] [dispatch_plans_screen.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/screens/dispatch_plans_screen.dart)
* Update the dispatch details view to match the home dashboard layout.

---

## Verification Plan

### Automated Verification
* Run `flutter analyze` inside the `VOSRoute/` project folder to ensure zero compiler errors or static warnings are introduced.

### Manual Verification
* Deploy/run the app in the simulator.
* Verify each screen in both **Dark Mode** and **Light Mode** to confirm consistent border roundness, spacing, typography scales, and alignment.
