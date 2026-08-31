# Clide

Clide is an open-source, local-first speech-to-text app for macOS. Press a shortcut, speak, and your words land wherever your cursor already is — transcribed on-device by default, with cloud providers available only if you bring your own API key.

Local-first. Private by default. Cloud only when you choose it.

See [clide.md](clide.md) for the full product specification and roadmap.

## Status

**0.1 — Sacred Path Prototype.** The core loop works end to end:

⌥+. → speak → local transcription (WhisperKit) → text inserted at the cursor, with clipboard-paste fallback.

Nothing beyond that (model manager, dashboard, onboarding, cloud providers, formatting) is built yet — see [handoff.md](handoff.md) for exactly what exists and what's next.

## Building

Requires Xcode 16+, macOS 14+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate
open Clide.xcodeproj
```

Or from the command line:

```sh
xcodegen generate
xcodebuild -project Clide.xcodeproj -scheme Clide -configuration Debug build
```

`Clide.xcodeproj` is generated from [project.yml](project.yml) and isn't checked into git — regenerate it after pulling.

## License

MIT — see [LICENSE](LICENSE).
