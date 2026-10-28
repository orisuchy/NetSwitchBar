# 05 — Wi-Fi names, Location permission, and menu detail

**Status:** ready-for-agent
**Model:** sonnet

## Parent

Parent: `.scratch/netswitchbar/spec.md`

## What to build

The app knows which Wi-Fi network it's on and shows more detail in the menu.

- Location adapter: request `CLLocationManager` authorization on first launch, with Info.plist usage text "Needed only to read the Wi-Fi network name for custom icons. Location is never stored or sent." If denied: a menu item "Grant Location access to enable per-network icons" that opens System Settings → Privacy & Security → Location Services.
- Path adapter adds `CoreWLAN` SSID and Wi-Fi association, plus Ethernet link status, into `NetworkSnapshot`.
- `ConnectionTracker`: display state wifi carries optional SSID; `switched` alerts include the SSID ("Switched to Wi-Fi: Office-5G"); the "Ethernet plugged in but not active" flag is set when Ethernet has link but isn't the active route; SSID changes while Ethernet is the active route produce no alerts.
- Menu status lines, e.g. "Active: Wi-Fi — Office-5G", "Ethernet: plugged in, not active".
- Everything works without Location (SSID simply nil).

## Acceptance criteria

- [ ] Tests: SSID appears in wifi display state and `switched` alert; nil SSID handled.
- [ ] Tests: SSID change while Ethernet is active → no alert; while Wi-Fi is active (held 3 s) → `switched` alert with new SSID.
- [ ] Tests: Ethernet link up + Wi-Fi active route → "plugged in but not active" flag set.
- [ ] App asks for Location on first launch; denial leaves app functional and shows the System Settings menu item.
- [ ] `make test` and `make app` pass.
- [ ] Manual check: menu shows the current SSID; with the cable plugged but Wi-Fi preferred (or cable with no link), the Ethernet hint line appears.

## Blocked by

- 02-change-notifications
