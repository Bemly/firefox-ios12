<p align="center">
  <img width="120" src="assets/logo.png" alt="Reynard logo" />
</p>

# Reynard Browser for iOS 12

**English** | [简体中文](README.zh.md)

> [!WARNING]
> This is an experimental fork of [minh-ton/reynard-browser](https://github.com/minh-ton/reynard-browser) that targets **iOS 12 only**. It is an AI-assisted revival project: expect bugs, missing features, and rough edges. There are no plans to upstream these changes — they deliberately trade code cleanliness for compatibility with a 2014-era OS.

Reynard is a **Gecko-based** web browser. Unlike every browser shipped on iOS — including Safari — which is forced to use the **WebKit** version bundled with the OS, Reynard ships its own engine: the same Gecko that powers Firefox on desktop and Android.

On iOS 12 the bundled WebKit is a decade old and most modern websites simply break. Because Gecko is compiled into the app, this port can load modern sites on hardware Apple abandoned long ago.

## Status

- **Modern web rendering** — complex sites (Google Search, GitHub, web apps) render and run their JavaScript.
- **SpiderMonkey JIT enabled in the main process** — this port is single-process, so the JIT is enabled directly in the app process (~18× faster JS than the interpreter baseline on a benchmark loop). No debugger attach or root helper is required on an AppSync-signed jailbroken device.
- **Video playback** — H.264 playback works. support HW Overlays, so high-resolution video is CPU-heavy.
- **WebGL rendering** — WebGL 1.0 contexts create and animate (verified with an on-device rotating-triangle probe page).

## Screenshots

Taken on-device (A7, iOS 12.5.8):

![On-device JIT benchmark](assets/screenshots/jit-bench.png)
*JIT benchmark — `RUNS[78,66,67,67]` warmup shape means Ion has reached steady state (~18× the interpreter baseline). The on-device diagnostics pages are listed under Settings.*

![720p H.264 test video playing](assets/screenshots/video-720p.png)
*720p H.264 test video playing (`readyState=4`, timestamp advancing).*

WebGL probe page (rotating triangle, `renderer=WebGL 1.0`):

| iPhone (30 fps) | iPad (55 fps) |
| --- | --- |
| <img src="assets/screenshots/webgl-anim-iphone.png" width="250" alt="WebGL animation on iPhone" /> | <img src="assets/screenshots/webgl-anim-ipad.png" width="500" alt="WebGL animation on iPad" /> |

## Requirements

- iPhone/iPad on **iOS 12.4 – 12.5.x** (A7 devices were the test target)
- A **jailbreak** (checkra1n works)
- [AppSync Unified](https://github.com/akemin-dayo/AppSync) installed from Cydia/Sileo

## Installation

There are no prebuilt releases yet — build the `.ipa` yourself (see [Building](#building)), then:

1. Copy the `.ipa` to the device (AirDrop won't work on iOS 12; use SSH/Filza/iTunes File Sharing).
2. Open it with [Filza](https://www.tigisoftware.com/default/?page_id=78) and install. AppSync Unified handles the signing.
3. Launch. JIT is enabled automatically at startup; if it cannot be enabled the browser silently falls back to the interpreter.

## Building

> [!WARNING]
> Build instructions are for reference only. No support is provided for build issues.

You need Xcode, [Python 3](https://www.python.org/downloads/), [Rust and Cargo](https://doc.rust-lang.org/cargo/getting-started/installation.html), and [ldid](https://formulae.brew.sh/formula/ldid).

Clone the repository.

```bash
git clone --recursive <this-repo-url>
cd reynard-browser-ios12
```

Download Gecko and apply the port's patches.

```bash
./tools/development/update-gecko.sh
./tools/development/apply-patches.sh
```

Build the dependencies and the Gecko engine (this takes a while the first time).

```bash
./tools/development/build-idevice.sh
./tools/development/build-gecko.sh
```

Then build the app itself. Without a paid signing certificate you can build with signing disabled and re-sign with `ldid` afterwards (the main binary wants the entitlements in `browser/Reynard/Entitlements/Reynard.private.entitlements`):

```bash
xcodebuild build -project browser/Reynard.xcodeproj -scheme Reynard \
  -configuration Debug -sdk iphoneos -arch arm64 \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="-" -derivedDataPath /tmp/ReynardDD
ldid -Sbrowser/Reynard/Entitlements/Reynard.private.entitlements \
  /tmp/ReynardDD/Build/Products/Debug-iphoneos/Reynard.app/Reynard
```

## Notes

The upstream project started as an experiment to run Gecko without Apple's [BrowserEngineKit](https://developer.apple.com/documentation/browserenginekit) so the engine could be back-ported to old iOS versions. This fork is that idea taken to its logical conclusion: a 2025-Gecko browser running on the original iPad mini's A7 chip, with the engine's JIT, media pipeline, and JavaScript security gates adjusted for a single-process, pre-iOS-13 world.

If you find this interesting, contributions and pointers are welcome — this is very much a learn-as-you-go project.

## Acknowledgements

- [minh-ton/reynard-browser](https://github.com/minh-ton/reynard-browser): the upstream iOS 13+ Gecko browser this fork builds on.
- [LiveContainer](https://github.com/LiveContainer/LiveContainer): app extension handling and NSExtension usage.
- [StikDebug](https://github.com/StephenDev0/StikDebug) and [idevice](https://github.com/jkcoxson/idevice): pairing-based JIT enablement support.
- [TrollStore](https://github.com/opa334/TrollStore): root helper spawning and JIT enablement techniques.
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS), [dolphin-ios](https://github.com/OatmealDome/dolphin-ios), [DukeX](https://github.com/MaftyManicEMU/DukeX), and [MeloNX](https://git.ryujinx.app/projects/MeloNX): various utility functions, private API usage, and JIT memory handling.
- [Pre-existing work](https://bugzilla.mozilla.org/show_bug.cgi?id=1882872) on bringing Gecko to iOS using BrowserEngineKit: most of the difficult engine integration.

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE), except for the `patches` directory containing the modifications to the Firefox Gecko engine and therefore is licensed under the [Mozilla Public License 2.0](LICENSE.firefox).
