# Handoff — Clide

Written by the agent that bootstrapped the project (2026-08-30). Read this before touching code — it'll save you from re-deriving decisions already made and re-researching API details already verified.

## ⚠️ Read this first: the permission-nagging trap

**Symptom:** the macOS Accessibility and/or Microphone dialogs keep reappearing on every launch, even though Clide is already enabled in System Settings.

**Cause:** development builds are ad-hoc signed (`CODE_SIGN_IDENTITY: "-"`), so **the signature changes on every rebuild**. macOS keys TCC grants to the signature, so a rebuilt Clide is a *different app* as far as TCC is concerned: Accessibility reads as untrusted and microphone reverts to "not determined" — while System Settings still shows an enabled "Clide" entry belonging to the previous binary.

**To actually re-grant after a rebuild:** remove Clide from the Privacy & Security list (select it, press −), then add the rebuilt `.app` again. Toggling the checkbox off/on is usually not enough. All of this disappears once real Developer ID signing exists (spec's 0.8 milestone).

**What this means for code — don't regress this:**

- `AXIsProcessTrustedWithOptions(prompt: true)` shows its dialog *every single time it's called* while untrusted. `AVCaptureDevice.requestAccess` shows its dialog whenever status is `.notDetermined`. Calling either at launch or on a timer produces the nagging loop.
- `PermissionsManager.accessibilityStatus()` / `microphoneStatus()` — **checking, never prompts.** Safe to poll.
- `promptForAccessibilityAccess()` / `requestMicrophoneAccess()` — **these show dialogs.** Only call in direct response to a user action.
- **Nothing prompts at app launch. Deliberate — don't add it back.**
- **Dictation never prompts for Accessibility at all.** `promptForAccessibilityAccess()` is reachable from exactly one place: the onboarding step's button. The microphone is requested from onboarding and from a dictation attempt (which is a user action, and `requestAccess` only shows a dialog while status is `.notDetermined`, so it can't loop within a session).

Also note **Accessibility is not required to dictate.** Without it Clide still transcribes and leaves the text on the clipboard (`InsertionOutcome.copiedNeedsAccessibility`). Both the AX insertion path *and* the clipboard fallback's synthetic ⌘V need the permission, which is why `TextInsertionService.insert` checks `AXIsProcessTrusted()` up front and copies without pasting when untrusted.

## ⚠️ Also read this: Clide is Apple Silicon only, and Release needs a flag

**FluidAudio (Parakeet) cannot compile for Intel.** It uses `Float16`, which is unavailable on x86_64 macOS. This is not a deployment-target or availability-annotation problem that can be worked around — the type doesn't exist there. Parakeet also depends on the Neural Engine, which Intel Macs lack.

So `clide.md` §5's "Apple Silicon first" is, in practice, Apple Silicon **only**, for as long as FluidAudio is a dependency. `Skills/Swift-helper.MD` says not to drop Intel without a strong technical reason; this is one, and it follows from a locked-in product decision rather than convenience. **If Intel support ever becomes a requirement, FluidAudio has to go.**

**Debug builds hide this** because they only build the active arch. Release builds both and fails.

**Build Release with `scripts/build-release.sh`**, which passes `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES` on the command line. That override is required: SPM package targets in an Xcode project do **not** reliably inherit the project's `ARCHS`/`EXCLUDED_ARCHS`, so FluidAudio still gets compiled for x86_64 and fails even though `project.yml` sets both. The settings are in `project.yml` anyway to state intent; the command-line flags are what actually work.

## ⚠️ Also read this: an NSEvent-monitor crash, and how to avoid it again

**`ShortcutPressMonitor` (the dashboard/onboarding keycap highlighter) crashed with `EXC_BAD_ACCESS` in `swift_task_isCurrentExecutorWithFlagsImpl`** the first time this build was actually run and left key-window focus for more than a few seconds. Full crash report: `~/Library/Logs/DiagnosticReports/Clide-2026-08-31-084137.ips`.

**Cause:** `NSEvent.addLocalMonitorForEvents(matching:handler:)`'s closure type isn't statically `@MainActor`, even though AppKit only ever invokes it on the main thread. The closure was written inline inside a `@MainActor` method and mutated a `@MainActor`-isolated `@Published` property (`self?.isOptionDown = …`) directly. That forces the Swift 6 runtime to do an executor-identity check before allowing the isolated access, and on this toolchain that check crashes (bad pointer deref inside `swift_getObjectType`) rather than just asserting — a toolchain bug, not a logic bug, but real either way.

**Fix applied:** compute the new value inside the closure, then hop with `DispatchQueue.main.async { self?.isOptionDown = isDown }` instead of mutating directly. Plain GCD dispatch never invokes the Swift-concurrency executor-comparison path, so it sidesteps the crash entirely. A one-frame-later keycap highlight is imperceptible.

**What this means for code:** any other `NSEvent` local/global monitor closure that touches a `@MainActor`/`@Published` property directly is at risk of the same crash on this toolchain. If you add one, route the mutation through `DispatchQueue.main.async` rather than assigning inline, even though the closure is in fact always called on the main thread.

## ⚠️ One more: a real design system now exists — use it, don't hand-roll

A full UI/animation pass (2026-08-31) replaced ad-hoc `.background(.quaternary)`/`Color.accentColor`/raw `.animation()` calls across every screen with a shared vocabulary in `Clide/UI/DesignSystem/` (see the source tree below). **Before writing any new view, check there first** — there is very likely already a primitive for what you need:

- `ClideTheme` — the palette (`Clide/Resources/Assets.xcassets`, light **and** dark), spacing/radius constants, and named `Animation` curves (`.snap`, `.gentle`, `.pop`, `.hover`).
- `.clideCard()`, `ClideSectionHeader`, `ClideRowGroup` — the card/list vocabulary every screen uses.
- `ClideBadge`, `ClideChip`, `StarRow`, `RatingRow`, `ClideRecDot` — small status/rating primitives.
- `.clidePrimary` / `.clideSecondary` / `.clideQuiet` button styles, `ClideIconButton`.
- `ClideEmptyState` — every "nothing here yet" surface uses this, never a bare `Text`.
- `.clideAnimation(_:value:)` / `.clideMotion { }` — **always use these instead of raw `.animation()`**. They collapse to a plain fade (or nothing, for `.clideMotion`) under Reduce Motion automatically; a bare `.animation()` call bypasses that and was the mechanism used to actually audit for missed cases (`grep -rn "\.animation(" Clide/` should only ever match the design-system internals and things already conditioned on `reduceMotion`).

**The palette is not invented** — it's pulled from the actual Clide marketing site (the Next.js app the user runs at `localhost:3000`, repo separate from this one). Real values, so don't restyle away from them without checking that site first: brand cyan `#2FB9E6`/`#1293C4`/`#0C7FAE`, canvas `#F4F9FD`, ink text `#0A2338` (a navy, not pure black — `ClideTheme.ink`), panel radius `16pt`, Montserrat/DM Sans/Fragment Mono (approximated here with SF Rounded / SF Mono since those aren't bundled fonts). The small pulsing dot on the dashboard's "Ready to dictate" row (`ClideRecDot`) is a deliberate homage to the site's `.rec-dot` eyebrow indicator, animation curve matched exactly (1.8s ease-in-out, 1→0.35 opacity, disabled under Reduce Motion).

**Visual QA note for whoever does this next:** screenshotting the running app via `screencapture -R<window-frame-from-AX>` is unreliable on this machine when the user has other windows open on other Spaces — AX geometry for Clide's window is correct even when it isn't the physically frontmost thing on screen, so region-captures can silently grab a *different, unrelated* window (this happened twice this session and briefly exposed unrelated content from the user's other conversations — nothing was acted on, but don't repeat it blindly). If you need to visually verify a screen, prefer asking the user to look, or explicitly confirm the target window is on the currently active Space first.

## What exists right now

Everything below **builds clean with zero warnings in app code** under Swift 6 strict concurrency, and **78 unit tests pass** (`xcodebuild -project Clide.xcodeproj -scheme Clide -destination 'platform=macOS' test`).

The sacred path:

> ⌥+. (toggle) → record mic → transcribe locally → deterministic cleanup → optional filler removal → text inserted at the focused cursor via Accessibility, or clipboard fallback.

Built so far, roughly spec milestones 0.1 through most of 0.5:

- **Dictation**: global hotkey (remappable), toggle-to-record, Escape to cancel, floating non-activating pill with a live mic-amplitude waveform, full state coverage and interactive ask-each-time actions.
- **Transcription**: `TranscriptionEngine` protocol with six implementations — WhisperKit, FluidAudio/Parakeet, Apple Speech (all local), plus Groq, Deepgram and AssemblyAI (BYOK cloud). `ModelManager` owns selection, engine caching, install state and download.
- **Model catalog**: eleven models with full metadata (§12), explainable hardware-fit ratings computed from real sysctl values (§13), a card/table model browser with search and filters (§14), and existing-model discovery over an allowlist of known paths (§15).
- **Formatting**: deterministic cleanup (always), conservative filler-word removal, and **real AI formatting** via Apple's on-device `SystemLanguageModel`, gated behind `#available(macOS 26)` and reporting a specific reason when unavailable.
- **Dashboard**: greeting, readiness card with live keycaps and a breathing status dot, today's totals led by time-saved, recent activity (when history is on, with its own empty state), model list, one-time Settings spotlight.
- **Onboarding**: welcome → mic → accessibility → model prep (with discovery) → real practice dictation → result with time saved → formatting prefs → done, with sliding step transitions and a spring-in success moment.
- **Settings**: shortcut recorder, launch at login, model picker + browser, all three cloud provider keys with Test Connection, formatting, privacy, developer-data consent, Debug Mode console.
- **Privacy**: opt-in transcript history (off by default, the only place transcripts are kept), counters-only statistics, opt-in developer diagnostics.
- **Diagnostics**: bounded local log, sanitized report, copy/export.
- **Design system** (`Clide/UI/DesignSystem/`): a real shared visual language — palette pulled from the actual clide.dev marketing site, spacing/radius/animation tokens, card/badge/button/empty-state primitives — applied consistently across every screen (dashboard, model browser, onboarding, pill, settings). Reduce Motion is respected everywhere via `.clideAnimation`/`.clideMotion`. See the dedicated ⚠️ section above before adding new UI.

### PENDING USER VALIDATION

Implemented but **not yet confirmed working by a human** — I can't speak into a microphone or click a System Settings dialog. Don't treat these as proven:

- microphone permission flow
- Accessibility permission flow
- live local transcription (WhisperKit / FluidAudio)
- focused-field insertion
- clipboard fallback
- the interactive ask-each-time pill (including the ✨ Format action)
- Deepgram / AssemblyAI / Groq transcription against real keys — the request shapes were built from current official docs but no call has been made with a live key
- Apple Speech transcription
- Apple Intelligence formatting output quality
- existing-model discovery actually finding anything (depends on what's on the machine)

The user has been asked to run the real test (⌥+., speak, watch text land in TextEdit) but had not reported a result at the time of writing. **Ask before assuming any of it works end to end.** Development deliberately continued past this point on explicit user instruction — implemented-but-unconfirmed is an acceptable base to build on; just don't call it verified.

### Known-inert / honest gaps

Things a reader might assume work but don't:

- **Developer-data sharing uploads nothing.** There's no Clide server. The consent toggle only unlocks Debug Mode; Settings states this outright. Don't add a fake upload.
- **AI formatting needs macOS 26 + Apple Intelligence enabled.** On anything older the picker is disabled and says why. There is no Clide Mini fallback formatter yet.
- **Sleep/wake recovery and mid-recording device disconnect** (§8) are not handled. Device *enumeration* reacts to changes, but a microphone unplugged mid-dictation isn't recovered from.
- **Model download shows no percentage** — the pill and browser show an indeterminate spinner, because neither runtime's `prepare()` surfaces progress through the current `TranscriptionEngine` protocol.
- **Existing-model discovery detects but doesn't yet reuse in place.** It reports what it finds; Clide still downloads its own copy into its own directory.
- Accuracy/speed scores in `ModelCatalog` are hand-written approximations from published benchmarks, not measurements. Hardware-fit ratings, by contrast, are computed from this Mac's real sysctl values. Don't present the first two as if they were measured.

## Repo layout

```
clide.md          product spec (source of truth — do not edit, per its own instructions)
handoff.md         this file
CLAUDE.md / AGENTS.md   point here + at clide.md
Skills/             Swift-helper.MD (macOS/Swift conventions this project follows) + a frontend-design skill doc
project.yml         XcodeGen spec — the actual source of truth for the Xcode project
scripts/build-release.sh  Release build; passes the arch flags FluidAudio needs
Clide/              app source (see below)
Clide.xcodeproj/    GENERATED by `xcodegen generate` — gitignored, do not edit by hand, do not commit
```

Run `xcodegen generate` after cloning or after any `project.yml` change, before opening the project. For Release, use `scripts/build-release.sh` (see the Apple Silicon note above). It's gitignored deliberately (see .gitignore) so there's one source of truth (`project.yml`) instead of hand-edited pbxproj XML.

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
  DictationPreferences.swift  toggle vs push-to-talk
Audio/
  AudioCaptureService.swift   AVAudioEngine → 16kHz mono Float32, lock-guarded buffer, amplitude callback
  AudioDeviceManager.swift    CoreAudio input enumeration; selection stored by UID, not the boot-unstable ID
  WAVEncoder.swift            16-bit PCM WAV for cloud uploads; local engines take Floats directly
Transcription/
  TranscriptionEngine.swift              protocol: transcribe(samples:) + optional prepare(); RecoveryAction
  WhisperKitTranscriptionEngine.swift    actor; in-memory transcribe(audioArrays:), no temp files
  FluidAudioTranscriptionEngine.swift    actor; AsrManager + TdtDecoderState
  AppleSpeechTranscriptionEngine.swift   SFSpeechRecognizer, on-device only or it refuses
  CloudProvider.swift                    the three BYOK services: keys, auth schemes, connection tests
  CloudRequest.swift                     shared HTTP + status-code → plain-language error mapping
  GroqTranscriptionEngine.swift          multipart, OpenAI-compatible
  DeepgramTranscriptionEngine.swift      raw WAV body, Token auth
  AssemblyAITranscriptionEngine.swift    upload → create → poll
Models/
  TranscriptionModelInfo.swift  the catalog + stable IDs, capabilities, sources
  ModelManager.swift            selection, engine cache, install state, download
  HardwareProfile.swift         this Mac via sysctl
  HardwareFit.swift             explainable 1-5 rating; carries its reasons, never just a number
  ExistingModelDiscovery.swift  allowlisted known paths only — never crawls user folders
  ModelBrowserView / ModelCard / ModelComparisonTable / ModelBrowserSheet
Formatting/
  TranscriptCleanup.swift       deterministic, always runs
  FillerWordRemover.swift       conservative; deliberately leaves like/so/well/you know alone
  FormattingPreferences.swift   three modes each, default Ask Each Time
  TranscriptFormatter.swift     protocol; availability + reason, so UI never lies about it
  AppleFormatter.swift          FoundationModels, #available(macOS 26) gated
  TranscriptPipeline.swift      composes the above; ask-each-time never alters text silently
Statistics/
  TimeSavedCalculator.swift     40 WPM baseline as a named constant; nil rather than a false claim
  DictationStatistics.swift     local counters only — never transcript text
  TranscriptHistory.swift       opt-in, off by default; the ONLY place transcripts are kept
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
  ClideWaveform.swift            shared amplitude-driven waveform bars (pill + previews)
  DesignSystem/
    ClideTheme.swift             palette, spacing/radius, named Animation curves, Reduce-Motion helpers
    ClideSurfaces.swift          .clideCard(), ClideSectionHeader, ClideRowGroup
    ClideBadges.swift            ClideBadge, ClideChip, StarRow, RatingRow, ClideRecDot
    ClideButtons.swift           .clidePrimary/.clideSecondary/.clideQuiet button styles, ClideIconButton
    ClideEmptyState.swift        the one "nothing here yet" component every screen uses
Resources/
  Assets.xcassets                the design system's colours, light + dark, sourced from clide.dev
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

The items this list used to name as unbuilt (Deepgram/AssemblyAI, mic selection, push-to-talk, transcript history, the AI formatter) are **done** — see "What exists right now" above; this section had gone stale. What's actually still open, roughly in order:

1. **Get the PENDING USER VALIDATION list above actually confirmed by a human.** Nothing involving a live microphone, a real API key, or Apple Intelligence output has been run end-to-end by a person yet. Everything else is less important than knowing the sacred path works.
2. **Model download progress** — `ModelManager.prepare()` and both local engines' `prepare()` still show an indeterminate spinner rather than a percentage; neither WhisperKit's nor FluidAudio's download call surfaces progress through the current `TranscriptionEngine` protocol, even though both libraries expose progress handlers internally.
3. **Existing-model discovery reuse-in-place** (§15) — `ExistingModelDiscovery` detects compatible models elsewhere on disk but Clide still downloads its own copy rather than referencing them.
4. **Sleep/wake recovery and mid-recording device disconnect** (§8) — device *enumeration* reacts to changes, but a microphone unplugged mid-dictation isn't recovered from.
5. **Clide Mini** local fallback formatter (§22) — today AI formatting is Apple Intelligence or nothing; there's no local model to fall back to on older macOS/hardware.
6. **Signing/notarization** (§41, 0.8 milestone) — also makes the Accessibility-nagging trap at the top of this file go away for good.

A full UI/animation pass (dashboard, model browser, onboarding, pill, settings, dev console) landed 2026-08-31 — see the design-system ⚠️ section near the top before styling anything new.

## Git / GitHub

Remote: `https://github.com/staraepp/Clide.git` (public; already had LICENSE+README, merged via `--allow-unrelated-histories`). Pushed regularly — check `git log origin/main..HEAD` for anything local-only.

Commits are checkpoint-sized, one coherent change each, and the messages explain *why* rather than restating the diff. Worth keeping up.
