# Spec: NetSwitchBar

**Status:** ready-for-agent

## Problem Statement

My Mac is plugged into Ethernet, but the cable is unreliable. When it drops, macOS silently falls back to Wi-Fi (or goes offline), and the menu bar only ever shows the Wi-Fi icon, so I can't tell at a glance whether I'm actually on the cable, on Wi-Fi, or offline. I only notice the cable failed when something gets slow or breaks. I also can't tell which Wi-Fi network I'm on without opening a menu.

## Solution

A small native macOS menu-bar app, NetSwitchBar, that replaces the system Wi-Fi icon (which the user hides via System Settings). Its icon always reflects the connection macOS is actually routing through: Ethernet, Wi-Fi, offline, or connected-but-no-internet. It posts a notification when the active connection changes or degrades, and collapses rapid on/off flapping into a single "unstable" summary. Users can assign a custom icon (SF Symbol name or emoji) to Ethernet, to each Wi-Fi network by name, and to unknown Wi-Fi networks.

## User Stories

1. As a Mac user on a flaky Ethernet cable, I want the menu-bar icon to show Ethernet when traffic goes over the cable, so that I know the cable is working.
2. As a Mac user, I want the icon to switch to Wi-Fi when traffic moves to Wi-Fi, so that I notice when the cable dropped.
3. As a Mac user, I want a crossed-out icon when there is no network route at all, so that I know I'm offline.
4. As a Mac user, I want a dimmed icon when I have a route but no internet, so that I can tell "connected but broken" apart from "working".
5. As a Mac user, I want the icon to follow the interface macOS actually routes through (not merely which interfaces are up), so that the icon is honest when both Ethernet and Wi-Fi are connected.
6. As a Mac user, I want a hint in the menu when the Ethernet cable is plugged in but is not the active route, so that I can see the cable has a problem even while Wi-Fi covers for it.
7. As a Mac user, I want a notification when the active connection changes and stays changed for about 3 seconds, so that I'm told about real switches without noise from momentary blips.
8. As a Mac user, I want the notification to name the Wi-Fi network I switched to, so that I know where my traffic is going.
9. As a Mac user, I want a notification when I go offline and when I'm back online, so that I know about outages without watching the icon.
10. As a Mac user, I want a notification when I'm connected but the internet is unreachable, so that I know the problem is upstream, not the link.
11. As a Mac user with a flaky cable, I want a single "Ethernet unstable: N drops in the last minute" notification when the connection flaps more than 3 times in a minute, so that I'm not spammed with one notification per drop.
12. As a Mac user with an unreliable Wi-Fi, I want the same flapping summary for Wi-Fi ("Wi-Fi unstable: N drops"), so that unstable Wi-Fi is also reported without spam.
13. As a Mac user, I want notifications to stay quiet while a connection is flapping, until it settles, so that the summary is the only message I see during instability.
14. As a Mac user on Ethernet, I want no notifications about Wi-Fi network changes while Ethernet is the active route, so that I'm only told about the connection I'm actually using.
15. As a Mac user, I want a menu toggle to turn notifications on and off, so that I can silence the app without quitting it.
16. As a Mac user, I want to set a custom icon for the connection I'm currently on via "Set icon for current connection…", so that customizing is one click away.
17. As a Mac user, I want to type either an SF Symbol name or an emoji as the icon, so that I can choose a native-looking symbol or a quick emoji.
18. As a Mac user, I want a live preview while choosing the icon, so that I can see it before saving.
19. As a Mac user, I want an invalid SF Symbol name to be rejected (not saved), so that my menu bar never shows a blank icon.
20. As a Mac user, I want a separate custom icon per Wi-Fi network name, so that home, office, and café networks are recognizable at a glance.
21. As a Mac user, I want a custom icon for Ethernet, so that the cable state uses my preferred symbol.
22. As a Mac user, I want a fallback icon for unknown Wi-Fi networks, so that networks without a mapping still look distinct.
23. As a Mac user, I want sensible default icons (cable.connector, wifi, wifi.slash) when I haven't customized anything, so that the app is useful immediately.
24. As a Mac user, I want my custom icons to survive app restarts, so that I set them once.
25. As a Mac user, I want the app to ask for Location permission on first launch with a clear explanation, so that it can read Wi-Fi names (required by macOS 14+) and I understand why.
26. As a Mac user who denies Location, I want everything except per-network icons and network names to keep working, so that denying permission doesn't break the app.
27. As a Mac user who denied Location, I want a menu item that opens the right System Settings pane, so that I can grant it later easily.
28. As a Mac user, I want the menu to show the current state in words (e.g. "Active: Wi-Fi — Office-5G", "Ethernet: plugged in, not active"), so that I get detail beyond the icon.
29. As a Mac user, I want a "Launch at Login" toggle, off by default, so that the app can start automatically when I choose.
30. As a Mac user, I want a "Quit" menu item, so that I can stop the app.
31. As a Mac user, I want the app to live only in the menu bar (no Dock icon), so that it stays out of the way.
32. As a Mac user, I want `make install` to build and install the app into ~/Applications without admin rights, so that installation is one command.
33. As a Mac user, I want the README and first-launch message to tell me how to hide the system Wi-Fi icon, so that I don't see two Wi-Fi icons.
34. As a Mac user, I want the internet-reachability check to be lightweight (no probes while offline or asleep), so that the app doesn't burden my system or network.
35. As a developer, I want `make test` to run the core logic tests with only the Command Line Tools installed, so that no Xcode install is needed.

## Implementation Decisions

- **Stack:** native Swift, Swift Package Manager, Swift 6 toolchain from the Command Line Tools only (no Xcode). Minimum macOS 14. A build script wraps the SwiftPM executable into `NetSwitchBar.app` with an Info.plist (`LSUIElement` = true, location usage description, bundle id) and ad-hoc code-signs it.
- **Two targets:**
  - `NetSwitchCore` — pure logic, no AppKit/Network/CoreWLAN imports. Fully unit-tested.
  - `NetSwitchBar` — thin executable app layer: OS adapters and UI. Manually verified.
- **`ConnectionTracker` (core, the main seam).** Consumes timestamped events, produces a display state and alerts. Time comes from an injected clock / event timestamps, never `Date()` inside the core.
  - Inputs:
    - `path(NetworkSnapshot)` — active interface (ethernet / wifi / none), whether Ethernet has link, whether Wi-Fi is associated, current SSID (optional).
    - `probe(succeeded: Bool)` — captive-portal probe result.
    - `tick` — time advanced (drives settle and flapping windows).
  - Outputs:
    - `displayState` — one of ethernet / wifi(ssid?) / offline / noInternet(underlying interface), plus a flag "Ethernet plugged in but not active".
    - `[Alert]` — switched(to:), offline, backOnline, noInternet, unstable(interface, dropCount).
  - Rules:
    - The icon state follows the active route immediately; **alerts** for a change fire only once the new active connection has held for 3 seconds (settle).
    - Flapping: if the active connection for a given interface (Ethernet or Wi-Fi) drops/changes more than 3 times within a 60-second window, emit one `unstable` alert for that interface and suppress further change alerts until it has been stable for the settle period plus the window clears.
    - No internet: 2 consecutive failed probes while a route exists → noInternet state + alert (subject to the same settle/flapping rules). A successful probe clears it.
    - Wi-Fi SSID changes while Ethernet is the active route produce no alerts.
    - Settle time (3 s), flapping threshold (>3 per 60 s), and probe-failure count (2) are constants, not settings.
- **`IconResolver` (core).** Pure function: (display state, icon mappings) → icon spec (SF Symbol name or emoji). Mapping keys: Ethernet, specific SSID, unknown Wi-Fi. Defaults: `cable.connector` (Ethernet), `wifi` (Wi-Fi), `wifi.slash` (offline). No-internet uses the underlying interface's icon rendered dimmed. Classifying user input as emoji vs SF Symbol name lives here; validating that an SF Symbol name exists is an app-layer check (needs AppKit).
- **Icon mappings storage:** `UserDefaults`, behind a small store interface the core can use with an in-memory fake.
- **App-layer adapters** (each only translates OS callbacks into tracker events or renders outputs):
  - Path adapter: `NWPathMonitor` for the active interface; `CoreWLAN` for Wi-Fi association and SSID; Ethernet link status for the "plugged in but not active" hint.
  - Probe adapter: `URLSession` GET of `http://captive.apple.com/hotspot-detect.html`, 5 s timeout, on every path change and every 30 s while a route exists; paused while offline and while the Mac sleeps (workspace sleep/wake notifications).
  - Notification adapter: `UNUserNotificationCenter`; honors the Notifications toggle (persisted).
  - Location adapter: `CLLocationManager` authorization request on first launch; menu item linking to Privacy & Security → Location Services when denied.
  - Menu bar UI: `NSStatusItem` with the resolved icon (SF Symbol image or emoji text), dimmed for noInternet; menu with status lines, Ethernet hint, "Set icon for current connection…", Notifications toggle, Launch at Login toggle (`SMAppService.mainApp`), Location item when needed, Quit.
  - Icon dialog: text field + live preview; rejects unknown SF Symbol names.
- **Build tooling:** `Makefile` with `test` (swift test with the Command Line Tools framework search/rpath flags for Swift Testing), `app` (build + bundle + sign), `install` (copy to `~/Applications`).
- **Privacy:** no location data stored or sent; the only network traffic is the captive-portal probe.

## Testing Decisions

- A good test drives the public seam with input events and asserts on outputs (display state, alerts, resolved icon). No assertions on private state, timers, or internal call order.
- `ConnectionTracker` tests: scripted, timestamped event sequences with an injected clock — settle (blip under 3 s → no alert; held change → one alert), offline/back-online, flapping on Ethernet and on Wi-Fi (exactly one `unstable` alert, then quiet until settled), no-internet after 2 failed probes and recovery, Wi-Fi SSID change while on Ethernet → no alert, Ethernet-plugged-but-inactive hint.
- `IconResolver` tests: defaults per state, SSID mapping wins over unknown-Wi-Fi fallback, Ethernet mapping, noInternet uses underlying interface icon dimmed, emoji vs symbol-name classification.
- Framework: Swift Testing, run via `make test` (verified working with Command Line Tools only when the framework path flags are passed and the package declares macOS 14).
- App layer is verified manually per ticket with a short checklist (unplug cable, toggle Wi-Fi, deny Location, etc.).
- No prior art — new repo.

## Out of Scope

- Changing or drawing over the system Wi-Fi icon, or changing any system network settings (service order, toggling interfaces).
- Custom image files as icons.
- A full preferences window listing all saved networks.
- Configurable settle/flapping/probe timings.
- Connection history, logging, or charts.
- Developer ID signing, notarization, distribution, auto-update.
- Interfaces other than Ethernet and Wi-Fi (VPN, iPhone USB/Bluetooth tethering are treated by whatever macOS reports; no special icons).

## Further Notes

- The user hides the system Wi-Fi icon themselves: System Settings → Control Center → Wi-Fi → "Don't Show in Menu Bar".
- Ad-hoc signing means macOS may re-ask for Location/notification permission after a rebuild — expected for a personal tool.
- `UNUserNotificationCenter` and Location both require running as a real `.app` bundle, not the bare SwiftPM executable.
