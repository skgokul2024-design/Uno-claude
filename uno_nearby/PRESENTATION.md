# UNO Nearby — Presentation

---

## Slide 1 — Title

# UNO NEARBY
### Offline Real-Time Multiplayer Card Game

Play Anywhere. Play Together. No Internet Required.

Built with Flutter · Android · Host-Authoritative Local Networking

---

## Slide 2 — Introduction

- A UNO-style card game for **2–4 players in the same room**
- Runs with **internet completely off** — no server, no cloud, no account
- Each player uses their own phone and sees only their own hand
- Also playable solo against AI opponents

Only requirement: devices share a local network (Wi-Fi or one phone's hotspot).

---

## Slide 3 — Problem Statement

Build a real multiplayer card game for nearby Android devices that:

- Requires **no internet connection**
- Requires **no cloud database or backend server**
- Provides **genuine** real-time multiplayer — not pass-and-play, not simulated
- Prevents any player from cheating by modifying their own game state

---

## Slide 4 — Existing System

| Approach | Limitation |
|---|---|
| Official UNO! / online card apps | Require internet + account + cloud matchmaking |
| Pass-and-play local apps | One shared device; hands aren't private |
| Bluetooth-only games | Slow, pairing friction, limited player count |

**Gap:** no good option for several people with phones but no connectivity.

---

## Slide 5 — Proposed System

A **host-authoritative local network game**:

- One device creates a room → becomes the authoritative host
- Other devices connect over the local Wi-Fi/hotspot as clients
- The host owns the *only* live game engine instance
- Clients send **action requests**; the host validates and broadcasts results

No device — including the host's own UI — mutates shared state directly.

---

## Slide 6 — Objectives

1. True 2–4 player multiplayer with zero internet dependency
2. Complete, correct UNO rule set (all action and wild cards)
3. Server-side validation preventing client-side cheating
4. Local SQLite statistics and persistent settings
5. Polished Material 3 mobile UI
6. Offline AI opponents for solo play

---

## Slide 7 — Features

- Create / join room with automatic nearby-room discovery
- Manual IP fallback when broadcast discovery is blocked
- Full ruleset: numbers, Skip, Reverse, Draw Two, Wild, Wild Draw Four
- Stacking draw penalties; configurable UNO penalty and draw rule
- Reconnection to the same seat after a dropped connection
- Statistics: games, wins, losses, win rate, high score, UNO calls
- Dark / light theme

---

## Slide 8 — Technology Stack

| Layer | Technology |
|---|---|
| UI | Flutter, Material 3 |
| Language | Dart |
| State management | Riverpod |
| Gameplay transport | TCP sockets (`dart:io`) |
| Discovery | UDP broadcast (`RawDatagramSocket`) |
| Persistence | SQLite (sqflite) |
| Platform | Android |

**No Firebase. No cloud database. No internet API.**

---

## Slide 9 — Architecture

```
UI (screens / widgets)
        ↓
Riverpod Providers
        ↓
NearbyConnectionService   ← networking abstraction
      ↙        ↘
HostServer      GameClient
    ↓
GameEngine  ← the single source of truth
```

The game engine never touches a socket. The UI never touches the rules.

---

## Slide 10 — Offline Networking

**Why not Wi-Fi Direct?** Flutter's Wi-Fi Direct plugins are thinly maintained and
fail inconsistently across Android versions and OEM skins. Rather than ship something
that *looks* implemented but breaks on real devices, we chose the reliable alternative:

- **Gameplay:** TCP, port 58910, newline-delimited JSON framing
- **Discovery:** UDP broadcast, port 58911, host announces every 1.5s
- **Fallback:** manual connect by the host's local IP address

All traffic stays on the local subnet — no uplink is used or required.

---

## Slide 11 — UNO Game Engine

- 108-card deck: 4 colors × 25 + 8 wilds
- `GameRules` — pure, stateless legality and turn-order functions
- `GameEngine` — the only component that mutates `GameState`
- Every action returns an `EngineResult`: either new state **or** a rejection reason

Validation on every move:

```
not your turn        → reject
card not in hand     → reject
card not playable    → reject
otherwise            → apply
```

---

## Slide 12 — Database

Five local SQLite tables — `players`, `games`, `game_results`, `statistics`, `settings`.

- Match results written when a game ends
- Aggregate statistics updated incrementally per player
- Settings persisted as key/value pairs

Everything stays on the device. Nothing is ever uploaded.

---

## Slide 13 — UI Screens

Home · Create Game · Join Game · Lobby · Game Table · Results · Settings · Statistics

Game table shows: opponent avatars and card counts, turn indicator, draw pile with
remaining count, discard pile, current color, your hand with unplayable cards dimmed,
UNO button, and a pending-draw-stack warning.

---

## Slide 14 — Testing

**Unit tests** — deck composition, rule legality, turn math, every action card's effect,
UNO penalty, win detection and scoring, JSON round-trips, client-state sanitization.

**Notable regression caught in development:** a Wild Draw Four played through the normal
"choose color afterwards" flow silently accumulated **no +4 penalty**, because the effect
switch sat inside the branch only taken when a color was supplied up front. Now fixed and
covered by a dedicated test.

**Remaining:** multi-socket networking integration tests and widget tests.

---

## Slide 15 — Results

- Complete game engine with full rule coverage and server-side validation
- Working host/client protocol with discovery, reconnection, and replay protection
- Sanitized state broadcasts — a client can never see another player's cards
- All primary screens implemented and wired to live state
- Local statistics and settings persistence

Verification with `flutter analyze` / `flutter test` / `flutter build apk` must be run
in a real Flutter environment — see README.

---

## Slide 16 — Future Scope & Conclusion

**Future work**
- Host migration on host disconnect (deliberately *not* faked in this version)
- Wi-Fi Direct as an additional discovery transport
- Audio, custom launcher icon and splash assets
- Tournament-legal Wild Draw Four challenge flow
- iOS support (engine and networking are already platform-agnostic Dart)

**Conclusion**

A fully offline, host-authoritative local multiplayer card game is practical on stock
Flutter APIs — no proprietary P2P plugin, no cloud, no internet.
