# 04 — No-internet detection

**Status:** done
**Model:** sonnet

## Parent

Parent: `.scratch/netswitchbar/spec.md`

## What to build

When a route exists but the internet is unreachable, the menu-bar icon is shown dimmed (underlying interface's icon) and the user gets a "Connected via <interface>, but no internet" notification. Recovery clears it.

- `ConnectionTracker` gains `probe(succeeded:)` events: 2 consecutive failures while a route exists → `noInternet(interface)` display state + `noInternet` alert (subject to settle/flapping rules). A success clears it.
- `IconResolver`: noInternet → underlying interface's icon, marked dimmed.
- Probe adapter: `URLSession` GET `http://captive.apple.com/hotspot-detect.html`, 5 s timeout; on every path change and every 30 s while a route exists. No probing while offline. Pause while the Mac sleeps (NSWorkspace sleep/wake notifications), resume on wake.

## Acceptance criteria

- [ ] Tests: 1 failed probe → still connected; 2 consecutive failures → noInternet state + one alert; success → back to normal state.
- [ ] Tests: probe results while offline do not change state.
- [ ] Tests: `IconResolver` returns the interface icon with dimmed flag for noInternet.
- [ ] App: no probes are sent while offline or asleep; interval 30 s while connected.
- [ ] `make test` and `make app` pass.
- [ ] Manual check: connect to a network with no upstream (e.g. phone hotspot with mobile data off) → dimmed icon + notification within ~1 min.

## Blocked by

- 02-change-notifications
