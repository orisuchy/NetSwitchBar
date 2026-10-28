# 06 — Custom icons per connection

**Status:** ready-for-agent
**Model:** sonnet

## Parent

Parent: `.scratch/netswitchbar/spec.md`

## What to build

The user can give the current connection its own icon.

- Menu item "Set icon for current connection…" opens a small dialog: text field + live preview. Input is either an SF Symbol name or an emoji. Unknown SF Symbol names are rejected (not saved) with an inline message. Option to reset to default.
- Mapping keys: Ethernet, a specific SSID, unknown Wi-Fi (fallback for Wi-Fi without a mapping or with nil SSID). When on Wi-Fi with a known SSID, the dialog sets the mapping for that SSID.
- Mappings persist in `UserDefaults` behind a small store interface; core tests use an in-memory fake.
- `IconResolver` uses mappings: SSID mapping > unknown-Wi-Fi mapping > default; Ethernet mapping > default. noInternet keeps the dimmed treatment on the resolved icon. Emoji vs symbol-name classification lives in core; SF Symbol existence check is in the app layer.
- Status item renders emoji as text and SF Symbols as template images.

## Acceptance criteria

- [ ] Tests: SSID mapping wins over unknown-Wi-Fi fallback; fallback used for unmapped SSID and nil SSID; Ethernet mapping applied; defaults when no mappings; noInternet with custom icon stays dimmed.
- [ ] Tests: emoji vs symbol-name classification.
- [ ] Invalid SF Symbol names are not saved; mappings survive restart.
- [ ] `make test` and `make app` pass.
- [ ] Manual check: set 🏠 for home Wi-Fi and `briefcase` for Ethernet → menu bar shows them; unplug/replug switches between them.

## Blocked by

- 05-wifi-names-and-detail
