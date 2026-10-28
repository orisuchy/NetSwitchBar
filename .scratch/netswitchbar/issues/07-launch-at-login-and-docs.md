# 07 — Launch at Login and docs

**Status:** done
**Model:** haiku

## Parent

Parent: `.scratch/netswitchbar/spec.md`

## What to build

- Menu toggle "Launch at Login" using `SMAppService.mainApp` register/unregister; default off; checkmark reflects the actual `SMAppService` status.
- README: what the app does, `make test` / `make app` / `make install`, how to hide the system Wi-Fi icon (System Settings → Control Center → Wi-Fi → "Don't Show in Menu Bar"), Location permission explanation, note that ad-hoc signing may re-prompt permissions after a rebuild.
- One-time first-launch hint (shown once, flag in `UserDefaults`) telling the user how to hide the system Wi-Fi icon.

## Acceptance criteria

- [ ] Launch at Login toggle registers/unregisters and the checkmark reflects real status after restart.
- [ ] README covers all items above.
- [ ] First-launch hint appears exactly once.
- [ ] `make test` and `make app` pass.

## Blocked by

- 01-walking-skeleton
