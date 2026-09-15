# UNO Nearby

Offline, real-time, local multiplayer UNO-style card game for Android. 2–4 players on the
same Wi-Fi network or hotspot play together with **zero internet, zero cloud services,
zero Firebase**.

> **Status of this build.** This repository contains a complete, from-scratch Dart/Flutter
> implementation of the game engine, the offline networking layer, the SQLite persistence
> layer, state management, and the primary screens (home, create room, join room, lobby,
> game table, results, settings, statistics). It was written in an environment with **no
> Flutter/Dart SDK and no internet access**, so `flutter pub get` / `flutter analyze` /
> `flutter test` / `flutter build apk` have **not** been run against it here — that has to
> happen on your machine (see "Build & Run" below). The code is real, not pseudocode, and
> the architecture is deliberately conservative so it compiles cleanly against the pinned
> dependency versions in `pubspec.yaml`, but treat the first `flutter analyze` you run as
> the actual verification step, not this document.

## Features

- Create or join a room over the local network — no account, no server, no signup.
- 2–4 human players, or 1 human + AI opponents ("Play with Computer").
- Full UNO-style rule set: number cards, Skip, Reverse, Draw Two, Wild, Wild Draw Four,
  stacking draw penalties, configurable UNO-call penalty, configurable draw rule.
- Host-authoritative networking: the room creator's device is the only source of truth;
  every play is validated server-side before any client's screen updates.
- Reconnection: a dropped player can rejoin the same seat within a grace window without
  losing their hand.
- Local SQLite statistics: games played, wins, losses, win rate, high score, UNO calls.
- Dark/light Material 3 theme, adjustable in Settings.

## Architecture

```
UI (screens/widgets)
   ↓
Riverpod providers (room / game / settings)
   ↓
NearbyConnectionService  (networking abstraction; game code never touches sockets directly)
   ↓                              ↓
HostServer (TCP server,      GameClient (TCP client,
 owns the GameEngine)         talks to the host)
   ↓
GameEngine (pure rules + authoritative state mutation)
```

The **host device** runs a `ServerSocket` on TCP port `58910` and owns the only live
`GameEngine` instance for the match. Every other device is a `GameClient` that sends
action requests (`PLAY_CARD`, `DRAW_CARD`, `CHOOSE_COLOR`, `UNO`) and receives sanitized
`GAME_STATE` snapshots — it can see its own hand and every other player's card *count*,
never their actual cards. The host's own human player goes through the identical
`GameEngine` validation path as a remote client, via `HostServer.handleLocal*` — there is
no "trusted" shortcut for the host's own moves.

### Why TCP sockets + UDP broadcast instead of Wi-Fi Direct

The spec calls for Wi-Fi Direct / Wi-Fi P2P "where supported." In practice, Flutter's
Wi-Fi Direct plugins are thinly maintained, behave inconsistently across OEM skins and
Android versions, and regularly fail silently on discovery. Rather than "pretend it
works" (explicitly disallowed by the spec), this build uses the most reliable offline
alternative:

- **Gameplay traffic**: raw TCP sockets (`dart:io`), newline-delimited JSON, host-authoritative.
- **Room discovery**: UDP broadcast on port `58911` — the host periodically announces its
  room; anyone on the "Join Game" screen sees it appear automatically.
- Both require only a shared local network: a Wi-Fi router, or one phone's mobile hotspot
  with the others joined to it. No internet uplink is used or required either way — all
  traffic stays on the local subnet.
- If auto-discovery doesn't find a room (some routers/hotspots block broadcast traffic),
  the Join screen has a manual "Connect by IP Address" fallback using the host's LAN IP,
  shown on the host's "Room Created" screen.

This keeps the `NearbyConnectionService` abstraction stable — if a more reliable Wi-Fi
Direct plugin becomes available later, only `networking/discovery.dart` and
`networking/host_server.dart`'s transport would need to change; the game engine and UI
never touch sockets directly.

## Permissions

Only what's actually required for local Wi-Fi discovery is requested (see
`android/app/src/main/AndroidManifest.xml` and `lib/core/services/permission_service.dart`):

| Permission | Why |
|---|---|
| `ACCESS_WIFI_STATE`, `ACCESS_NETWORK_STATE` | Read the device's local IP to display/connect |
| `CHANGE_WIFI_STATE` | Some OEMs require this to receive UDP broadcasts reliably |
| `ACCESS_FINE_LOCATION` (API ≤ 32) | Android ties Wi-Fi scanning to location on older versions |
| `NEARBY_WIFI_DEVICES` (API 33+) | Replaces location for Wi-Fi discovery on modern Android |
| `INTERNET` | Required by the OS to open *any* socket, including local-only ones — no internet host is ever contacted |

The app requests these at runtime with an explanation shown first, and handles
granted / denied / permanently-denied without crashing (see `permission_service.dart`).

## Project Structure

See `lib/` — organized into `core/`, `models/`, `game/` (engine, rules, deck, AI),
`networking/` (host, client, discovery, framing), `database/`, `providers/`, `screens/`,
`widgets/`. Tests live in `test/`.

## Build & Run

### Option A — Build in the cloud (no local install needed)

This repo ships a GitHub Actions workflow at `.github/workflows/build-apk.yml` that
builds a debug APK for you:

1. Create a new GitHub repository and push this project to it.
2. Open the **Actions** tab. The `Build APK` workflow runs automatically on push, or
   trigger it manually with **Run workflow**.
3. When it finishes, open the run and download the `uno-nearby-debug-apk` artifact from
   the Artifacts section. Unzip it to get `app-debug.apk`.
4. Transfer that APK to each phone and install it (allow "install from unknown sources").

The workflow regenerates the Android Gradle scaffolding with `flutter create` on every
run, which is why `android/` is **not** committed here — see `.gitignore`. That keeps the
scaffolding in sync with whatever Flutter version is building, and means you never hand-
maintain Gradle files. `tool/add_permissions.py` then injects the local-networking
permissions into the generated manifest.

`flutter analyze` and `flutter test` run with `continue-on-error: true` so you still get a
testable APK while warnings are being cleaned up. Remove those two lines from the workflow
once analysis is clean, so a regression fails the build.

Other cloud options: **FlutLab.io** (browser-based Flutter IDE that can build APKs
directly — create a project there and paste in `lib/` and `pubspec.yaml`) and
**Codemagic** (free tier, Flutter-specific CI, connects to a Git repo).

> Note: generic "website to APK" converters (AppsGeyser, WebIntoApp, Median, PWABuilder)
> will **not** work for this project. They wrap a web page in a WebView; they cannot
> compile Dart, and a WebView has no access to the TCP/UDP sockets this game's offline
> multiplayer is built on.

### Option B — Build locally

Requires the Flutter SDK (stable channel) and an Android toolchain on your machine —
neither is available in the environment this code was generated in.

Because `android/` isn't committed, generate it first:

```bash
flutter create --platforms=android --org com.unonearby --project-name uno_nearby .
python3 tool/add_permissions.py
rm -f test/widget_test.dart
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

`flutter create` will overwrite `lib/main.dart` and `pubspec.yaml` with its templates —
back both up first and restore them afterwards, exactly as the CI workflow does.

The APK lands at `build/app/outputs/flutter-apk/app-debug.apk`.

If `flutter analyze` reports issues: this codebase was written by hand against the API
surfaces of the pinned package versions in `pubspec.yaml` (Riverpod 2.5, sqflite 2.3,
network_info_plus 6.0, permission_handler 11.3, uuid 4.4) as of this writing. If a newer
major version has since shipped with breaking API changes, pin back to the versions above
or adjust the small number of call sites `flutter analyze` points to — the architecture
itself does not depend on any particular package version.

## Testing With Two or More Real Phones

1. Make sure all phones are on the **same Wi-Fi network**, or connect them all to **one
   phone's mobile hotspot**. Turn off mobile data / airplane mode is fine as long as the
   local network is up — internet connectivity is not needed by the app at all.
2. Install the debug APK on every phone (`flutter build apk --debug`, then transfer/install
   `build/app/outputs/flutter-apk/app-debug.apk`, or `flutter install` with each phone
   connected via USB/adb one at a time).
3. On **Phone A**: `CREATE GAME` → enter a name → pick player count → `CREATE ROOM`. Note
   the IP address shown on the "Room Created" screen as a fallback.
4. On **Phones B, C, D**: `JOIN GAME`. The room should appear under "Nearby Games" within
   a couple of seconds; tap `JOIN`. If it doesn't appear, use "Connect by IP Address" with
   Phone A's IP.
5. On **Phone A**, once 2–4 players show as connected: `START GAME`.
6. Play should synchronize instantly across all phones: playing a card, drawing, calling
   UNO, and picking a Wild color all update every screen immediately.
7. To test reconnection: turn off Wi-Fi on one client mid-game, then turn it back on
   within the grace window — that device should rejoin the same seat with its hand intact.

## Known Limitations

- **Host migration is not implemented.** If the host's device disconnects or closes the
  app, the match cannot continue — clients are shown "Host disconnected, the current game
  cannot continue" and returned to the home screen, per the spec's explicit instruction
  not to fake host migration. A future version could add this once a specific
  election/handoff protocol is designed and tested across real host failures.
- **Manual room-code join isn't a true directory lookup.** Because there's no rendezvous
  server (by design — no internet), a room "code" only has meaning once you're already
  connected; the practical join fallback is by local IP address, which is what "Connect by
  IP Address" does. The code is shown for players to visually confirm they joined the
  right room.
- UDP broadcast discovery can be unreliable on networks/routers with client isolation
  (common on some public/guest Wi-Fi). A personal hotspot from the host's phone avoids
  this entirely and is the recommended setup for testing.
- This build has not been run through `flutter build apk` in the authoring environment
  (no SDK/network access there) — validate with `flutter analyze` and `flutter test`
  locally before your first real-device test.
- Splash screen / custom launcher icon assets are referenced structurally
  (`assets/icons/`, `assets/images/`) but no bitmap assets are bundled in this text-only
  handoff; add your own PNGs (or generate an icon with `flutter_launcher_icons`) before a
  release build.
- Sound/music/vibration settings are persisted and exposed in Settings, but no audio
  asset files or an audio-playback package are wired up yet — add e.g. `audioplayers` and
  files under `assets/sounds/` to complete that feature.

## Troubleshooting

- **"No nearby games found"**: confirm both devices are on the same Wi-Fi/hotspot, that
  the Nearby/Location permission was granted, and try "Connect by IP Address."
- **Connection drops immediately**: some routers isolate clients from each other
  ("AP/client isolation") — use a phone hotspot instead of shared public Wi-Fi.
- **Build fails on a specific package**: check `flutter pub outdated` and either pin to
  the versions listed above or update the small number of affected call sites.
