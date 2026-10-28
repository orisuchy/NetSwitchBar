# NetSwitchBar

A small macOS menu-bar app that shows which connection your Mac is actually using: Ethernet, Wi-Fi, offline, or connected but without internet. It is built for an unreliable Ethernet cable, where macOS quietly falls back to Wi-Fi and you otherwise only notice when something breaks.

- The icon follows the route macOS sends traffic through.
- A notification fires when the active connection changes or degrades and has held for about 3 seconds.
- Rapid drops are collapsed into one "unstable" summary instead of one notification per drop.
- You can set a custom icon (SF Symbol name or emoji) for Ethernet, for each Wi-Fi network by name, and for unknown Wi-Fi networks.
- The app lives only in the menu bar, with no Dock icon.

Requires macOS 14 or later. Builds with the Command Line Tools only; Xcode is not needed.

## Build, test, install

```sh
make test     # run the core logic tests
make app      # build and bundle build/NetSwitchBar.app (ad-hoc signed)
make install  # copy the app to ~/Applications (no admin rights needed)
```

Then open `~/Applications/NetSwitchBar.app`.

## Hide the system Wi-Fi icon

NetSwitchBar replaces the system Wi-Fi icon, so hide the system one to avoid two Wi-Fi icons:

System Settings → Control Center → Wi-Fi → **Don't Show in Menu Bar**

The app shows this hint once, on first launch.

## Permissions

- **Location.** macOS 14 and later only reveals the Wi-Fi network name to apps with Location permission. NetSwitchBar asks on first launch so it can read the name for per-network icons. Location is never stored or sent. If you deny it, everything still works except per-network icons and network names. A menu item then opens Privacy & Security → Location Services so you can grant it later.
- **Notifications.** Optional. Used for connection-change and outage alerts. The menu has a Notifications toggle.
- **Network.** The only traffic is a lightweight captive-portal check (`http://captive.apple.com/hotspot-detect.html`). It is not sent while offline or while the Mac sleeps.

## Launch at Login

The menu has a **Launch at Login** toggle, off by default. The checkmark reflects the real login-item status. If macOS asks you to approve the item in System Settings → General → Login Items, the checkmark stays off until you approve it.

## Rebuilds may re-prompt

The app is ad-hoc signed, not Developer ID signed. After a rebuild with `make app` or `make install`, macOS may ask again for Location and notification permission. This is expected for a personal tool.
