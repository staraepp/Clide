# Handoff — Clide

Written by the agent that bootstrapped the project (2026-08-30). Read this before touching code — it'll save you from re-deriving decisions already made and re-researching API details already verified.

## ⚠️ Read this first: the Accessibility permission trap

**Symptom:** the macOS Accessibility dialog keeps reappearing even though Clide is already ticked in System Settings → Privacy & Security → Accessibility.

**Cause:** development builds are ad-hoc signed (`CODE_SIGN_IDENTITY: "-"`), so **the signature changes on every rebuild**. macOS keys the TCC grant to the signature, so a rebuilt Clide is a *different* app as far as TCC is concerned. System Settings still shows an enabled "Clide" entry, but it belongs to the previous binary, and `AXIsProcessTrusted()` returns false.

**To actually re-grant after a rebuild:** remove Clide from the Accessibility list (select it, press −), then add the rebuilt `.app` again. Toggling the checkbox off/on is usually not enough. This disappears once real Developer ID signing exists (spec's 0.8 milestone).

**What this means for code — don't regress this:** `AXIsProcessTrustedWithOptions(prompt: true)` shows the system dialog *every single time it is called* while untrusted. Calling it at launch, on a timer, or on each dictation attempt produces exactly the nagging loop above. So:

- `PermissionsManager.accessibilityStatus()` / `AXIsProcessTrusted()` — **checking, never prompts.** Use freely, including in polls.
- `PermissionsManager.promptForAccessibilityAccess()` — **shows the dialog.** Only ever call it in direct response to a user action. It is currently called from exactly two places: the onboarding Accessibility step's button, and once per launch on the first dictation attempt (guarded by `hasPromptedForAccessibility`).
- Nothing prompts at app launch. Deliberate — don't add it back.

Also note **Accessibility is not required to dictate.** Without it Clide still transcribes and leaves the text on the clipboard (`InsertionOutcome.copiedNeedsAccessibility`). Both the AX insertion path *and* the clipboard fallback's synthetic ⌘V need the permission, which is why `TextInsertionService.insert` checks `AXIsProcessTrusted()` up front and copies without pasting when untrusted.

## What exists right now

Everything below **builds clean with zero warnings in app code** under Swift 6 strict concurrency, and **34 unit tests pass** (`xcodebuild -project Clide.xcodeproj -scheme Clide -destination 'platform=macOS' test`).

The sacred path:

> ⌥+. (toggle) → record mic → transcribe locally → deterministic cleanup → optional filler removal → text inserted at the focused cursor via Accessibility, or clipboard fallback.

Built so far, roughly spec milestones 0.1 through most of 0.5:

- **Dictation**: global hotkey (remappable), toggle-to-record, Escape to cancel, floating non-activating pill with a live mic-amplitude waveform and interactive ask-each-time actions.
- **Transcription**: `TranscriptionEngine` protocol with three implementations — WhisperKit (local), FluidAudio/Parakeet (local), Groq (BYOK cloud). `ModelManager` owns selection and caches one engine per model.
- **Formatting**: deterministic cleanup (always), conservative filler-word removal, three-mode preferences. AI formatting preference exists but is **honestly inert** — no on-device formatter has been integrated, and the UI says so.
- **Dashboard**: greeting, readiness card with live keycaps, today's totals led by time-saved, model list with explainable hardware-fit ratings.
- **Onboarding**: welcome → mic → accessibility → model prep → real practice dictation → result with time saved → formatting prefs → done.
- **Settings**: shortcut recorder, launch at login, model picker, Groq key + Test Connection, formatting, privacy, developer-data consent, Debug Mode console.
- **Diagnostics**: bounded local log, sanitized report, copy/export.

### PENDING USER VALIDATION

Implemented but **not yet confirmed working by a human** — I can't speak into a microphone or click a System Settings dialog. Don't treat these as proven:

- microphone permission flow
- Accessibility permission flow
- live local transcription (WhisperKit / FluidAudio)
- focused-field insertion
- clipboard fallback
- the interactive ask-each-time pill

The user has been asked to run the real test (⌥+., speak, watch text land in TextEdit) but had not reported a result at the time of writing. **Ask before assuming any of it works end to end.** Development deliberately continued past this point on explicit user instruction — implemented-but-unconfirmed is an acceptable base to build on; just don't call it verified.

### Known-inert / honest gaps

Things a reader might assume work but don't:

- **AI formatting** does nothing. No Apple on-device model or Clide Mini formatter is wired up. `TranscriptPipeline` never applies or prompts for it.
- **Developer-data sharing uploads nothing.** There's no Clide server. The consent toggle only unlocks Debug Mode; Settings states this outright. Don't add a fake upload.
- **Deepgram and AssemblyAI** are not implemented — Groq is the only cloud provider.
- **Transcript history** (§27) does not exist. Statistics are deliberately counters-only and hold no transcript text, so history is a separate feature, not an extension of statistics.
- **Microphone selection, push-to-talk, device-change/sleep-wake handling** (§8, §7) are not implemented.
- Accuracy/speed scores in `ModelCatalog` are hand-written approximations from published benchmarks, not measurements. Hardware-fit ratings, by contrast, are computed from this Mac's real sysctl values.

## Repo layout

```
clide.md          product spec (source of truth — do not edit, per its own instructions)
handoff.md         this file
CLAUDE.md / AGENTS.md   point here + at clide.md
Skills/             Swift-helper.MD (macOS/Swift conventions this project follows) + a frontend-design skill doc
project.yml         XcodeGen spec — the actual source of truth for the Xcode project
Clide/              app source (see below)
Clide.xcodeproj/    GENERATED by `xcodegen generate` — gitignored, do not edit by hand, do not commit
```

Run `xcodegen generate` after cloning or after any `project.yml` change, before opening the project. It's gitignored deliberately (see .gitignore) so there's one source of truth (`project.yml`) instead of hand-edited pbxproj XML.

### Clide/ source tree

```
App/
  ClideApp.swift            @main SwiftUI App — NSApplicationDelegateAdaptor + the Settings scene
  AppDelegate.swift          menu bar status item, owns the one DictationCoordinator and the window controllers
  ClideStorage.swift          ~/Library/Application Support/Clide/ + /Models/ path helpers
Permissions/
  PermissionsManager.swift    mic + Accessibility. NOTE the check-vs-prompt split described at the top of this file
Dictation/
  DictationCoordinator.swift  the sacred-path state machine — start here to understand the flow
  HotkeyName.swift           KeyboardShortcuts.Name.toggleDictation, default ⌥+.
Audio/
  AudioCaptureService.swift   AVAudioEngine → 16kHz mono Float32, lock-guarded buffer, amplitude callback
  WAVEncoder.swift            16-bit PCM WAV for cloud uploads; local engines take Floats directly
Transcription/
  TranscriptionEngine.swift              protocol: transcribe(samples:) + optional prepare()
  WhisperKitTranscriptionEngine.swift    actor; in-memory transcribe(audioArrays:), no temp files
  FluidAudioTranscriptionEngine.swift    actor; AsrManager + TdtDecoderState
  GroqTranscriptionEngine.swift          BYOK, OpenAI-compatible endpoint, + testConnection
Models/
  TranscriptionModelInfo.swift  the catalog + stable model IDs and metadata
  ModelManager.swift            active selection (persisted) and per-model engine cache
  HardwareProfile.swift         this Mac via sysctl
  HardwareFit.swift             explainable 1-5 rating; carries its reasons, never just a number
Formatting/
  TranscriptCleanup.swift       deterministic, always runs
  FillerWordRemover.swift       conservative; deliberately leaves like/so/well/you know alone
  FormattingPreferences.swift   three modes each, default Ask Each Time
  TranscriptPipeline.swift      composes the above; ask-each-time never alters text silently
Statistics/
  TimeSavedCalculator.swift     40 WPM baseline as a named constant; nil rather than a false claim
  DictationStatistics.swift     local counters only — never transcript text
Diagnostics/
  DiagnosticsLog.swift          bounded ring buffer; records what happened, never what was said
  DiagnosticsReport.swift       the ONE place a report is assembled, so the never-include rule is enforceable
  DeveloperSettings.swift       opt-in consent, off by default, unlocks Debug Mode
  DeveloperConsoleView.swift    local console
TextInsertion/
  TextInsertionService.swift    AX insertion, secure-field subrole check, clipboard fallback, untrusted handling
Dashboard/
  DashboardView.swift, DashboardWindowController.swift, ShortcutPressMonitor.swift
Onboarding/
  OnboardingState.swift, OnboardingView.swift, OnboardingWindowController.swift
Settings/
  SettingsView.swift, LaunchAtLogin.swift
UI/
  PillState.swift / DictationPillView.swift / DictationPillWindow.swift  non-activating NSPanel
  KeycapView.swift              reusable physical keycap, used by dashboard + onboarding
  HardwareFitBadge.swift        stars + "why this rating?" popover
ClideTests/                     Swift Testing; 34 tests over the pure logic
```

## Technical decisions already made (don't re-litigate without a reason)

- **Deployment target: macOS 14.0.** Started at 13.0 (WhisperKit's own `Package.swift` only needs 13, verified from the v1.1.0 tag source). Raised to 14 when FluidAudio was added, because FluidAudio's `Package.swift` declares `.macOS(.v14)` — a genuine dependency requirement, not convenience, which is the bar `Skills/Swift-helper.MD` sets. Don't raise it further without the same justification.
- **WhisperKit** (`github.com/argmaxinc/WhisperKit`, pinned `from: 1.0.0`, resolved to 1.1.0). The package itself is now internally named `argmax-oss-swift` with multiple library products (`ArgmaxOSS`, `WhisperKit`, `TTSKit`, `SpeakerKit`) — `project.yml` pins `product: WhisperKit` specifically. Model used: `tiny.en`, chosen for onboarding-speed reasons per spec — swap easily via `WhisperKitTranscriptionEngine(modelName:)`. Transcription goes through the in-memory `transcribe(audioArrays: [[Float]])` API, not file paths — no temp files written to disk. Models download automatically from Hugging Face into `~/Library/Application Support/Clide/Models/` (not WhisperKit's own default cache location — passed explicitly via `downloadBase`).
- **KeyboardShortcuts** (`sindresorhus/KeyboardShortcuts`, pinned `from: 1.0.0`, resolved to 1.17.0) for the global hotkey — this was an explicit user decision (asked via AskUserQuestion) over hand-rolling Carbon `RegisterEventHotKey`, specifically because `Skills/Swift-helper.MD` says not to add third-party deps without asking first.
- **App Sandbox: off. Hardened Runtime: off. Code signing: ad-hoc (`-`).** The Accessibility API needed for text insertion into other apps doesn't work under App Sandbox at all — confirmed via research, not assumed. Distribution is DMG + GitHub Releases (not the Mac App Store), so sandboxing was never required anyway. No paid Apple Developer identity is configured on this machine (`security find-identity -v -p codesigning` → 0 identities) — signing/notarization is explicitly a later milestone (spec's "Clide 0.8" beta hardening phase), not blocking for local dev.
- **Escape-to-cancel** is implemented (global `NSEvent` monitor for keyCode 53 while listening) even though it wasn't explicitly called out for 0.1 — it's cheap and directly part of spec §7's "Global Dictation" requirements for the same interaction being built.
- Toggle-to-record (press once to start, press again to stop) was chosen over push-to-talk for 0.1 — simpler state machine, and the spec allows either as a v1.0 option. Push-to-talk still needs doing.
- **FluidAudio** (`github.com/FluidInference/FluidAudio`, pinned `from: 0.15.0`, resolved to 0.15.6). Uses `AsrManager` + `AsrModels.downloadAndLoad(to:version:)` with `TdtDecoderState`. Note there is also a `UnifiedAsrManager` with a simpler `transcribe([Float]) -> String`; `AsrManager` was chosen because it's what the project's own GettingStarted doc documents. Default version `.v2` (English-only, better English recall than v3 per their docs). License is **Apache 2.0, not MIT** as `clide.md` §9 claims — both are fine for an MIT app, but the spec's claim should be corrected by a human (this agent was told not to edit `clide.md`).
- **Singletons** (`ModelManager.shared`, `FormattingPreferences.shared`, `DictationStatistics.shared`, `DiagnosticsLog.shared`, …) are used for app-wide state that genuinely has one instance. They're injectable via initializer defaults where it matters (`DictationCoordinator`), so this isn't a testability dead end.
- **Statistics deliberately store no transcript text.** That's what keeps them independent of the not-yet-built transcript history and its separate privacy switch. Don't "improve" `DictationRecord` by adding the text.
- **The pill is click-through except when it's asking something** (`PillState.isInteractive` drives `ignoresMouseEvents`). It must never sit in front of the user's work catching clicks.

## Things verified from primary sources, not memory (in case something breaks and you're debugging)

Went and checked the actual SDK headers / library source rather than trusting training data, because an earlier research pass got some of this wrong (e.g. said WhisperKit needs macOS 14 — it doesn't) or the library moved (WhisperKit's repo now points at `argmax-oss-swift`). Places this mattered:
- `kAXTrustedCheckOptionPrompt` is declared *without* `const` in `AXUIElement.h`, so Swift imports it as a mutable global and Swift 6 strict concurrency refuses to let you read it at all (not even with `nonisolated(unsafe)` on a wrapper — tried that, didn't work). Fix used: skip the SDK symbol entirely and pass the literal string `"AXTrustedCheckOptionPrompt"` instead — it's a stable, documented dictionary key. See `PermissionsManager.swift`.
- Secure-field detection uses `kAXSubroleAttribute == "AXSecureTextField"`, not the role — there's no `kAXSecureTextFieldRole` constant, only `kAXSecureTextFieldSubrole`.
- `KeyboardShortcuts.Name` isn't `Sendable`, so its static instances need explicit `@MainActor`.

- `AsrModels.downloadAndLoad` and WhisperKit's `downloadBase` both point at `ClideStorage.modelsDirectory`, so all model data lives under `~/Library/Application Support/Clide/Models/` rather than each library's own cache.

## What's next

Roughly in dependency order, all still unbuilt:

1. **Get the pending-validation list above actually confirmed by a human.** Everything else is less important than knowing the sacred path works.
2. **Deepgram + AssemblyAI** BYOK providers (§10). Groq's engine is a reasonable template. Verify both APIs from their real docs — a research pass during this session got a Deepgram doc URL that 404'd, so nothing about either API is confirmed yet. AssemblyAI is upload → create → poll, so it needs a different shape from Groq's single request.
3. **Microphone selection + device-change/sleep-wake handling** (§8). Selecting an input device on `AVAudioEngine` means setting `kAudioOutputUnitProperty_CurrentDevice` on the input unit *before* starting the engine.
4. **Push-to-talk** as an alternative to toggle (§7).
5. **Transcript history** (§27) with its own hard off switch, separate from statistics.
6. **Model download progress + model manager UI** (§14) — engines currently download silently inside `prepare()`.
7. **An actual AI formatter** (§22), which would make the existing preference mean something.
8. **Signing/notarization** (§41, 0.8 milestone) — which also makes the Accessibility trap at the top of this file go away.

## Git / GitHub

Remote: `https://github.com/staraepp/Clide.git` (public; already had LICENSE+README, merged via `--allow-unrelated-histories`). Pushed regularly — check `git log origin/main..HEAD` for anything local-only.

Commits are checkpoint-sized, one coherent change each, and the messages explain *why* rather than restating the diff. Worth keeping up.
