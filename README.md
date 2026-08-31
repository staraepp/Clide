# Clide

Clide is an open-source, local-first speech-to-text app for macOS. Press a shortcut, speak, and your words land wherever your cursor already is — transcribed on-device by default, with cloud providers available only if you bring your own API key.

Local-first. Private by default. Cloud only when you choose it.

See [clide.md](clide.md) for the full product specification and roadmap.

## Status

**In development.** The core loop works end to end:

⌥+. → speak → local transcription → cleanup → text inserted at the cursor, with clipboard fallback.

Also built: eleven models across WhisperKit, Parakeet, Apple Speech and three
BYOK cloud providers; a model browser with hardware-fit ratings; onboarding;
a dashboard; opt-in transcript history; and on-device AI formatting via Apple
Intelligence where available.

See [handoff.md](handoff.md) for exactly what exists, what still needs testing
on real hardware, and what's deliberately not built yet.

## Building

Requires Xcode 16+, macOS 14+ on **Apple Silicon**, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

Clide is Apple Silicon only: the Parakeet runtime uses `Float16`, which doesn't exist on Intel macOS.

```sh
xcodegen generate
open Clide.xcodeproj
```

Or from the command line:

```sh
xcodegen generate
xcodebuild -project Clide.xcodeproj -scheme Clide -configuration Debug build
```

For a Release build, use the script — it passes architecture flags that the
Swift Package dependencies need:

```sh
./scripts/build-release.sh
```

`Clide.xcodeproj` is generated from [project.yml](project.yml) and isn't checked into git — regenerate it after pulling.

## License

MIT — see [LICENSE](LICENSE).
