# 03 — Flapping summary (Ethernet and Wi-Fi)

**Status:** ready-for-agent
**Model:** sonnet

## Parent

Parent: `.scratch/netswitchbar/spec.md`

## What to build

When a connection flaps, the user gets one summary notification instead of a stream. If the active connection for an interface (Ethernet or Wi-Fi) drops/changes more than 3 times within a 60-second window, `ConnectionTracker` emits a single `unstable(interface, dropCount)` alert ("Ethernet unstable: 5 drops in the last minute" / "Wi-Fi unstable: 4 drops in the last minute") and suppresses further change alerts until the connection has been stable for the settle period and the window clears. Thresholds are constants.

## Acceptance criteria

- [ ] Tests: 4+ Ethernet drops within 60 s → exactly one `unstable(ethernet, n)` alert, no individual `switched` alerts after it while flapping.
- [ ] Tests: same for Wi-Fi.
- [ ] Tests: after the connection settles and the window clears, normal `switched` alerts resume.
- [ ] Tests: 3 drops within 60 s → no `unstable` alert (threshold is >3).
- [ ] Notification text matches the examples above.
- [ ] `make test` and `make app` pass.

## Blocked by

- 02-change-notifications

## Comments

- From ticket 01: the core uses Double-second timestamps (Swift Testing cannot import Foundation alongside Testing with Command Line Tools only). The app clock currently uses systemUptime, which stops during sleep. For the 60 s flapping window, use a clock that keeps running through sleep (e.g. wall-clock or continuous time).
