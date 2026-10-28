# 08 — Visual icon picker in the "Set icon" dialog

**Status:** done
**Model:** sonnet

## Parent

Parent: `.scratch/netswitchbar/spec.md` (follow-up to 06-custom-icons; user feedback: people don't remember SF Symbol names)

## What to build

The "Set icon for current connection…" dialog gets a **"Choose icon…"** button that opens a visual picker, so the user can pick by sight instead of by name.

- The picker is a popover (or sheet) with a **grid of ~80 curated SF Symbols** relevant to networks and places: e.g. house, building, briefcase, cup/café, airplane, train, car, bed, books/school, cart, cross/hospital, globe, network, wifi variants, cable.connector, antenna, phone, laptop, desktop, server, lock, shield, star, heart, flag, bolt, leaf, moon, sun. Each cell shows the symbol image; hover/tooltip shows its name.
- A **search field** above the grid filters the curated list by name.
- An **"Emoji…"** button opens the macOS emoji picker (Character Viewer) so the chosen emoji lands in the text field.
- Clicking a symbol fills the existing text field with its name and updates the live preview. Save/Reset/Cancel behave as today.
- **Typing an SF Symbol name or emoji in the text field still works** exactly as before (user requirement), including validation of unknown names.
- The curated list lives in one place (core or app constant); every entry must exist on macOS 14 — filter out any name `NSImage(systemSymbolName:)` returns nil for, so no blank cells.
- Fix while here: the validation message should appear inline as the user types (not only after Save), and must not be clipped.

## Acceptance criteria

- [ ] "Choose icon…" button opens a grid of curated SF Symbols with images and name tooltips; search filters it.
- [ ] Clicking a symbol fills the text field and updates the preview; Save stores it as before.
- [ ] "Emoji…" opens the system emoji picker and the chosen emoji goes into the field.
- [ ] Typing a symbol name or emoji still works; invalid names are rejected inline.
- [ ] No blank cells (unavailable symbols filtered out).
- [ ] If list filtering/search logic is in core, it has tests; `make test` and `make app` pass.
- [ ] Manual check: open the dialog on Wi-Fi, pick `house.fill` from the grid, Save → menu bar shows it.

## Blocked by

- 06-custom-icons (done)
