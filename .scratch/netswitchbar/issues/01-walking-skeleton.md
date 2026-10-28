# 01 — Walking skeleton: active-route icon in the menu bar

**Status:** ready-for-agent
**Model:** sonnet

## Parent

Parent: `.scratch/netswitchbar/spec.md`

## What to build

The thinnest end-to-end NetSwitchBar: a SwiftPM package with two targets — `NetSwitchCore` (pure logic, no AppKit/Network/CoreWLAN imports) and `NetSwitchBar` (thin executable app layer). The app runs as a menu-bar-only `.app` (no Dock icon) whose icon reflects the interface macOS actually routes through: Ethernet, Wi-Fi, or offline.

- `ConnectionTracker` (core) consumes timestamped events (`path(NetworkSnapshot)` for now; design the event enum so `probe` and `tick` can be added later) and exposes a display state (ethernet / wifi / offline). Time comes from event timestamps / an injected clock, never `Date()` inside the core.
- `IconResolver` (core) maps display state → icon spec with defaults: `cable.connector` (Ethernet), `wifi` (Wi-Fi), `wifi.slash` (offline).
- Path adapter (app): `NWPathMonitor` → `NetworkSnapshot` events. `NSStatusItem` renders the resolved icon. Menu has a status line and Quit.
- Build tooling: `Makefile` with `test` (swift test with Command Line Tools Swift Testing flags), `app` (build, wrap into `NetSwitchBar.app` with Info.plist: `LSUIElement`=true, bundle id, location usage description placeholder; ad-hoc codesign), `install` (copy to `~/Applications`).
- Package declares `platforms: [.macOS(.v14)]` at package level.

Verified fact (orchestrator probe): with Command Line Tools only, Swift Testing works when invoked as
`swift test -Xswiftc -F$F -Xlinker -F$F -Xlinker -rpath -Xlinker $F` where `F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks`, and the package declares macOS 14. XCTest is NOT available.

## Acceptance criteria

- [ ] `make test` passes with only Command Line Tools installed.
- [ ] Tests drive `ConnectionTracker` with snapshot events and assert display state: ethernet active → ethernet; wifi active → wifi; no route → offline; both up with Ethernet as active route → ethernet.
- [ ] Tests assert `IconResolver` default icons for each state.
- [ ] `make app` produces a signed `NetSwitchBar.app`; `make install` copies it to `~/Applications` without sudo.
- [ ] Launched app shows only in the menu bar (no Dock icon), with a status line and a working Quit item.
- [ ] Manual check (for the user): unplug the cable → icon becomes Wi-Fi; turn Wi-Fi off too → offline icon; reconnect → back to Ethernet.

## Blocked by

None - can start immediately
