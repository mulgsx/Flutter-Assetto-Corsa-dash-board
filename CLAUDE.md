# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Assetto Corsa real-time telemetry dashboard — a Flutter app that receives UDP packets from the Assetto Corsa racing simulator and displays live metrics (RPM, speed, gear, lap times) in a landscape-oriented dashboard.

## Common Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run in debug mode
flutter run -d windows   # Run on Windows
flutter run -d android   # Run on Android
flutter build apk        # Build Android APK
flutter build windows    # Build Windows executable
flutter analyze          # Lint/static analysis
flutter test             # Run tests
flutter test test/widget_test.dart  # Run specific test
```

## Architecture

**Single-screen app** with three source files in `lib/`:

- [lib/main.dart](lib/main.dart) — App entry point, entire telemetry pipeline (UDP socket, handshake, state management, main UI). `ACDashboardAppState` owns all state.
- [lib/ac_converter.dart](lib/ac_converter.dart) — Binary packet data classes: `ACHandshaker` (12-byte outgoing) and `RTCarInfo` (328-byte incoming telemetry).
- [lib/ac_drawer.dart](lib/ac_drawer.dart) — Sidebar drawer UI for IP settings and connection controls.

**State management**: `ValueNotifier` + `ValueListenableBuilder` (no Provider/Riverpod). Key notifiers in `ACDashboardAppState`: `rpmNotifier`, `statusNotifier`, `currentDisplayedIpNotifier`, `packetCountNotifier`.

**UI throttling**: Packets arrive at ~120Hz but UI updates are throttled to 5Hz via `_displayUpdateTimer` (200ms interval) to prevent rendering bottlenecks.

## UDP Protocol

- Port: **9996** (Assetto Corsa default)
- Default target IP: `192.168.0.0` (user-configurable, persisted via SharedPreferences)
- Handshake: Client sends `ACHandshaker` with `operationId=0` (CONNECT), server replies with 408-byte `HandshakerResponse`, then client sends `operationId=1` (CAR_INFO) to begin streaming.
- Packets: 328-byte `RTCarInfo` structs with little-endian floats. Key fields: `speedKmh` (offset 4), `engineRPM` (offset 12), `gear` (offset 268).

See [AC_Telemetry_Implementation_Guide_jp.md](AC_Telemetry_Implementation_Guide_jp.md) for the full binary protocol reference (in Japanese).

## Platform Notes

- **Orientation**: Forced landscape-only via `SystemChrome.setPreferredOrientations`.
- **System UI**: Immersive sticky mode (hidden status/nav bars), transparent overlays.
- Targets Android, iOS, Windows, Linux, macOS, Web — but primarily designed for mobile use alongside a gaming PC.
