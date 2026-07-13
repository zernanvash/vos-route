## Brand & Style
The brand personality is technical, reliable, and premium, specifically optimized for high-performance fleet management and night-friendly HUD environments. The aesthetic sits at the intersection of **Corporate Modern** and **Glassmorphism**, emphasizing high-density data clarity without sacrificing a futuristic, energetic feel. 

The visual identity is defined by a deep-space foundation—utilizing a dark-mode-first approach—with vibrant, functional accents. It evokes a sense of "mission control" precision, where critical information is layered through tonal depth and subtle translucency.

## Layout & Spacing
The layout follows a systematic 8px-based grid (with 4px increments for micro-spacing) to create a structured, professional rhythm.

- **Grid:** Use a 12-column fluid grid for desktop dashboards and a 4-column grid for mobile interfaces.
- **Margins & Gutters:** Standard page margins should be 24px (`lg`), with 16px (`md`) gutters between cards and primary interface elements.
- **Content Density:** In data-heavy dispatch views, use tighter vertical spacing (`sm` or `xs`) to maximize the information displayed above the fold.

## Elevation & Depth
Depth is created through tonal layering and glassmorphism rather than heavy shadows.

- **Layering:** Elements are stacked by moving from the deepest neutral color (`#080810`) to lighter surfaces (`#0F0F1A`, then `#1A1A22`).
- **Borders:** All containers must feature a thin, crisp 1px border colored `#1F1F27`.
- **Active States:** Use a light overlay or a glassmorphic "frosted" tint to indicate active or hover states on cards.
- **Shadows:** If shadows are used for extreme elevation (e.g., modals), they should be highly diffused, low-opacity, and tinted with a dark blue or neutral base to maintain the cohesive dark-mode aesthetic.

## Components
- **Buttons:** Primary CTAs are solid `#3B6EF0` with bold white-equivalent text. Secondary buttons should use the tertiary background (`#1A1A22`) or an outline-only style.
- **Status Chips:** These feature a soft, semi-transparent background derived from the status color (e.g., 15% opacity green) paired with a solid dot and solid text of the same hue (e.g., `#22C55E`).
- **Input Fields:** Use the secondary background (`#0F0F1A`) as the fill. They must have a subtle border that transforms into a vibrant primary blue (`#3B6EF0`) only upon focus.
- **Cards:** The workhorse of the fleet system. Cards should have the secondary background, a 1px border, and 12px rounded corners. Use subtle vertical padding for trip stops and fleet status lines.
- **Iconography:** Use modern, linear outline icons (Feather/Lucide style). Icons should be 20px or 24px and use secondary text colors by default, switching to primary or status colors only when active.
- **Checkboxes & Radios:** These should utilize the primary blue accent when checked, with a high-contrast tick or center dot.