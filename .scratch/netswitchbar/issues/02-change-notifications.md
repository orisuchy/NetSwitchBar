# 02 — Change notifications with settle

**Status:** done
**Model:** sonnet

## Parent

Parent: `.scratch/netswitchbar/spec.md`

## What to build

When the active connection changes and holds for 3 seconds, the user gets a macOS notification ("Switched to Wi-Fi", "Back on Ethernet"). Going offline and coming back online also notify. The icon still updates immediately; only alerts wait for the settle.

- `ConnectionTracker` gains a `tick` event and emits `[Alert]`: `switched(to:)`, `offline`, `backOnline`. Settle time 3 s is a constant.
- Notification adapter: `UNUserNotificationCenter` (requests authorization; requires running as the `.app`).
- Menu gets a "Notifications" toggle, persisted in `UserDefaults`, default on. A timer in the app layer feeds `tick` events.

## Acceptance criteria

- [ ] Tests: change held ≥3 s → exactly one `switched` alert; blip shorter than 3 s that reverts → no alert.
- [ ] Tests: route lost and held → `offline` alert; route regained and held → `backOnline` alert.
- [ ] Notifications appear when running the installed app; toggling Notifications off suppresses them and the setting survives restart.
- [ ] `make test` and `make app` pass.
- [ ] Manual check: unplug the cable for >3 s → "Switched to Wi-Fi" notification; replug → "Back on Ethernet".

## Blocked by

- 01-walking-skeleton
