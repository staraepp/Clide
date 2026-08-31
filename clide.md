# Clide — Product Specification & Roadmap

**Status:** Working product plan  
**Target platform:** macOS  
**Implementation:** Native Swift + SwiftUI  
**License:** MIT  
**Business model:** Free, open-source, non-profit passion project  
**Primary goal:** Make system-wide speech-to-text fast, private, flexible, polished, and genuinely pleasant to use.

---

# 1. Product Definition

Clide is a native macOS speech-to-text app built around one core interaction:

> **Global shortcut → speak → transcribe → optional cleanup → insert at cursor**

That is the sacred path. Everything else exists to make that interaction more reliable, configurable, private, and enjoyable.

Clide supports:

- **Local transcription models**
- **Cloud transcription providers using the user's own API key**
- **Optional local text formatting**
- **System-wide text insertion**
- **No Clide account**
- **No paid Clide subscription**
- **No Clide-hosted transcription service**
- **No required telemetry**
- **No ad tracking**
- **No transcript uploads to Clide servers**

Clide should feel like a polished native Mac utility, not a SaaS dashboard wrapped in a desktop shell.

---

# 2. Privacy Philosophy

## Default behavior

Clide is **private by default**.

When using a local transcription model:

```text
Microphone
    ↓
Clide
    ↓
Local transcription model
    ↓
Optional local formatter
    ↓
Target text field
```

No transcript or audio needs to leave the Mac.

When the user intentionally selects a cloud provider:

```text
Microphone
    ↓
Clide
    ↓
User-selected provider API
    ↓
Clide
    ↓
Target text field
```

The audio is sent **directly to the provider selected by the user** using the user's own API key. It does not pass through Clide infrastructure.

API keys are stored in **macOS Keychain**.

## Product language

Avoid claiming that every configuration is always 100% local, because a user may intentionally enable a cloud provider.

Preferred wording:

> **Local-first. Private by default. Cloud only when you choose it.**

---

# 3. Optional Developer Data / Debug Mode

Clide does **not** collect developer diagnostics by default.

A user may explicitly opt in from Settings.

Suggested consent copy:

> **Share developer data with Clide**
>
> I consent to share developer diagnostic data with Clide. Enabling this also unlocks Debug Mode, including a local console and additional developer tools.
>
> Your transcriptions, recorded audio, API keys, custom vocabulary, clipboard contents, and other sensitive data will remain on your device and will never be included in Clide diagnostic uploads.
>
> Please read our **Privacy Policy** before enabling this. It should only take a few minutes.

### Requirements

- **Off by default**
- Explicit opt-in only
- Reversible at any time
- Clearly separated from transcription history
- Clearly separated from local statistics
- Never bundled into another consent toggle
- Never required to use Clide
- Never required to access support

### Data Clide may collect when enabled

Examples of acceptable diagnostic data:

- Clide version
- macOS version
- Mac model identifier
- CPU / Apple Silicon generation
- memory class
- selected transcription runtime
- selected model **ID**
- selected formatting runtime
- feature flags
- permission states
- anonymous error codes
- crash information
- stack traces
- model load failures
- provider connection failures
- transcription latency measurements
- text-insertion success/failure state
- whether clipboard fallback was required
- download failures
- sanitized logs
- performance timing
- app launch / shutdown problems

### Data Clide must NEVER upload

Even in Debug Mode:

- Transcript text
- Recorded microphone audio
- Imported audio/video files
- API keys
- Authentication tokens
- Passwords
- Secure-field contents
- Clipboard contents
- User-created vocabulary
- Text replacements
- Full document contents
- Raw Accessibility tree contents
- Personally identifying text captured from the active field

### Debug Mode

When developer-data sharing is enabled, Settings gains a **Developer** section containing:

- Live local Clide console
- Log level selector
- Copy sanitized diagnostics
- Export diagnostics bundle
- Model/runtime status
- Permission status
- Audio pipeline status
- Active provider status
- Current formatter status
- Text-insertion strategy
- Last error details
- Performance timings
- Reset Clide caches
- Re-run onboarding checks
- Open model storage folder

The console itself can remain fully local.

A manual **Export Diagnostics** option should also exist for users who do not enable automatic developer-data sharing.

---

# 4. v1.0 Scope

The goal is for **most of the core Clide experience to exist in 1.0**, rather than shipping an extremely bare prototype.

However, reliability of dictation always outranks feature count.

---

# 5. Native macOS Application

**Target: v1.0**

- Swift
- SwiftUI
- Native menu bar integration
- Native Settings window
- Native materials where appropriate
- Launch at login
- Apple Silicon first
- Signed
- Notarized
- Distributed as a DMG
- GitHub releases
- MIT source release

Clide should feel native rather than like a web app inside a desktop wrapper.

---

# 6. Onboarding

**Target: v1.0**

Onboarding should be short, interactive, and visually polished.

## Step 1 — Welcome

Example:

> **Your voice, wherever you type.**
>
> Press a shortcut, speak naturally, and Clide puts the words where your cursor already is.

## Step 2 — Permissions

Request permissions one at a time.

### Microphone

Explain why it is needed before macOS shows the system permission prompt.

### Accessibility

Explain that Accessibility permission is used to insert text into the currently selected editable field.

Clide should automatically detect when permission has been granted instead of relying on an "I did it" button.

## Step 3 — Temporary Onboarding Model

Clide owns a normal app-support directory:

```text
~/Library/Application Support/Clide/
```

Model storage:

```text
~/Library/Application Support/Clide/Models/
```

Temporary onboarding model:

```text
~/Library/Application Support/Clide/Models/onboarding/
```

The onboarding model is:

- Small
- Fast to load
- Included with or prepared during installation
- Copied into Clide's Application Support directory
- Used for the onboarding test
- Deleted after onboarding unless the user chooses to keep it

Clide must not modify its signed `.app` bundle after installation.

## Step 4 — Interactive Shortcut Tutorial

Default shortcut:

> **⌥ + .**

The visual keycaps react to real keyboard input.

```text
╭─────╮   ╭─────╮
│  ⌥  │ + │  .  │
╰─────╯   ╰─────╯
```

When a key is physically pressed:

- keycap depresses
- slight scale animation
- spring-back animation

When the full shortcut is pressed:

- floating Clide pill appears
- microphone begins listening
- waveform becomes active
- user says any sentence
- result is displayed and/or inserted into an onboarding test field

Suggested copy:

> **Try Clide**
>
> Press **⌥ + .** and say any sentence.

## Step 5 — Formatting Preferences

### AI Formatting

Choices:

- Always Off
- Ask Each Time **(default)**
- Always On

### Filler Word Removal

Choices:

- Always Off
- Ask Each Time **(default)**
- Always On

Show a simple before/after example.

## Step 6 — Existing Models

During setup, Clide searches **known compatible model locations**.

If compatible models are found:

> **We found models you may already have.**

Allow:

- Use with Clide
- Ignore
- Locate another model manually

Clide should avoid unnecessarily duplicating existing models when the runtime safely allows referencing them in place.

## Step 7 — Completion

Example:

> **You're ready.**
>
> You now know how to start Clide.
>
> Want to change your shortcut, privacy settings, models, or anything else?

Open the dashboard.

The Settings icon receives a one-time spotlight animation with a short explanation.

---

# 7. Global Dictation

**Target: v1.0**

Default shortcut:

> **⌥ + .**

Features:

- Remappable shortcut
- Push-to-talk mode
- Toggle-to-record mode
- Cancel with Escape
- Shortcut conflict detection
- Shortcut reset option

---

# 8. Audio Pipeline

**Target: v1.0**

Requirements:

- Microphone capture
- Microphone selector
- Device-change handling
- Headset disconnect handling
- Sleep/wake recovery
- Audio normalization/resampling
- Streaming where supported
- Buffered transcription where required
- Voice Activity Detection where useful
- No unnecessary raw audio files written to disk
- Graceful cancellation
- Graceful timeout handling

---

# 9. Local Transcription Engines

**Target: v1.0**

## Whisper

Runtime:

- **WhisperKit**
- Argmax
- Swift-native
- MIT
- Core ML
- Apple Neural Engine where supported

Potential families:

- Whisper Tiny
- Whisper Base
- Whisper Small
- Whisper Medium
- Whisper Large variants
- Turbo variants where supported

## Parakeet

Runtime:

- **FluidAudio / FluidInference**
- Swift-native
- MIT
- Core ML
- Apple Neural Engine where supported

FluidAudio can also provide:

- VAD
- speaker diarization
- related audio intelligence features

Those capabilities do not automatically make Meeting Mode a v1 feature.

## Apple Speech

**Target: v1.0 if stable; otherwise v1.1**

Expose Apple's native speech runtime as another transcription choice when available.

Models UI should indicate:

- managed by macOS
- no Clide model download required
- supported languages
- streaming support
- OS requirement
- hardware compatibility

---

# 10. Cloud STT Providers

**Target: v1.0**

BYOK only.

Initial providers:

- Groq
- Deepgram
- AssemblyAI

Potential later providers:

- OpenAI transcription
- additional user-requested APIs
- custom provider support

Requirements:

- API key stored in Keychain
- Test Connection button
- Provider-specific settings
- Clear indication that audio is leaving the Mac
- No Clide proxy
- No API key in logs
- No automatic fallback to cloud unless the user explicitly enables it

---

# 11. Capability System

**Target: v1.0**

Each transcription option reports capabilities such as:

- Local / Cloud
- Streaming transcription
- Batch transcription
- Language detection
- Supported languages
- Word timestamps
- Segment timestamps
- Speaker diarization
- Custom vocabulary
- Translation
- Neural Engine support
- Core ML support
- Estimated memory requirement

The UI adapts to model/provider capabilities.

---

# 12. Model IDs and Metadata

**Target: v1.0**

Every model has a stable internal ID.

Examples:

```text
whisper.large-v3
whisper.small.en
fluid.parakeet-tdt-0.6b-v3
groq.whisper-large-v3
deepgram.nova-3
apple.speech.system
```

Metadata:

- ID
- Display name
- Runtime
- Provider
- Version
- Download size
- Installed size
- Accuracy score
- Speed score
- Hardware-fit score
- Language support
- Streaming support
- Offline availability
- Architecture
- Recommended RAM
- Recommended hardware
- Download source
- Checksum
- Description
- Tags
- Experimental/stable state

Model catalog information should be data-driven rather than hardcoded into individual Swift views.

---

# 13. Hardware-Aware Ratings

**Target: v1.0**

Each model can expose:

### Accuracy

> ★★★★★

General model-quality estimate, clearly labeled approximate.

### Speed

> ★★★★☆

Based on model/runtime characteristics and, when available, local benchmark data.

### Hardware Fit

> ★★★★★ Excellent for this Mac

Personalized based on:

- Mac model
- Apple Silicon generation
- RAM
- available memory
- Neural Engine support
- runtime support
- expected real-time factor
- model size
- power requirements
- compatibility

Clicking the rating explains it.

Example:

> **Why this rating?**
>
> ✓ Runs on Apple Neural Engine  
> ✓ Low memory requirement  
> ✓ Expected faster-than-real-time transcription  
> ✓ Optimized for Apple Silicon

---

# 14. Model Manager

**Target: v1.0**

Features:

- Browse models
- Search models
- Filter Local / Cloud / Installed / Compatible
- Pretty card view
- Optional compact comparison/table view
- Download
- Pause/cancel where practical
- Delete
- Verify download
- Show size
- Show installed storage
- Show runtime
- Show language support
- Show hardware rating
- Show accuracy/speed
- Select active model
- Show active model
- Show model status
- Open model folder

Nothing multi-gigabyte should be bundled in the main DMG unless absolutely necessary.

---

# 15. Existing Model Discovery

**Target: v1.0**

Clide inspects known safe/compatible locations for already-installed models.

If found:

- identify model
- verify compatibility
- show source location
- offer Use with Clide
- avoid duplication where safe

Also provide:

> **Locate Model…**

Clide should never crawl arbitrary user folders without permission.

---

# 16. Floating Clide Pill

**Target: v1.0**

The floating pill is one of Clide's primary interaction surfaces.

It is **not** a custom notch overlay.

## States

- Idle
- Listening
- Transcribing
- Formatting
- Waiting for formatting choice
- Ready
- Inserted
- Copied to clipboard
- Error
- No microphone
- Permission required
- Model loading
- Model downloading
- Provider unavailable

## Listening

- responsive waveform driven by microphone amplitude
- subtle spring animation
- optional short partial transcript

## Processing

- waveform collapses into a processing animation

## Formatting

- subtle sparkle/shimmer treatment

## Inserted

- checkmark
- soft spring
- fade/shrink away

## Clipboard fallback

> **Hm… we couldn't add the text there.**
>
> We copied it to your clipboard instead.

## Secure field

Do not silently insert into secure/password fields.

Recommended:

> **This looks like a secure field.**
>
> Clide didn't insert the transcript.
>
> **[Copy Transcript]**

Do not automatically copy sensitive text from a secure-field interaction unless the user chooses to.

---

# 17. Text Insertion

**Target: v1.0**

Preferred:

- macOS Accessibility API
- focused editable text element

Fallback:

- clipboard-based paste

Clipboard fallback must:

1. save current clipboard state
2. insert/paste transcription
3. restore safely when possible
4. avoid racing against new clipboard content created by the user

Target compatibility testing:

- Safari
- Firefox
- Chrome
- VS Code
- Xcode
- Notes
- Mail
- Discord
- Slack
- Notion
- Obsidian
- Google Docs
- Microsoft Office apps
- common Electron apps
- common native macOS text fields

Preferred product wording:

> **Works across the apps and text fields you already use, with clipboard fallback when direct insertion isn't available.**

---

# 18. Live Transcript Animation

**Target: v1.0 in the Clide pill**

As the user speaks:

- partial transcript may appear inside the pill
- new words fade/slide in
- animation should feel alive without becoming distracting
- text should not cause chaotic pill resizing

The default v1 implementation should **not continuously rewrite text inside another app while the STT model is still changing its partial hypothesis**.

---

# 19. True Live Typing Into Other Apps

**Target: Experimental after v1.0**

Potential feature:

> Insert/update words directly inside the focused text field while the user is still speaking.

Deferred because streaming hypotheses can revise previous text.

Risks:

- cursor movement
- rich text
- undo behavior
- browser editors
- Google Docs
- partial-text replacement
- user clicking elsewhere mid-dictation
- app-specific Accessibility behavior

---

# 20. Transcript Cleanup Pipeline

**Target: v1.0**

```text
Speech
  ↓
STT
  ↓
Deterministic cleanup
  ↓
Optional formatter
  ↓
Optional filler-word removal
  ↓
Text insertion
```

Formatting failure must never prevent basic dictation from succeeding.

---

# 21. Deterministic Cleanup

**Target: v1.0**

No LLM required.

Potential features:

- capitalization
- punctuation normalization
- whitespace cleanup
- obvious repeated-fragment cleanup
- paragraph cleanup where deterministic

Keep this lightweight and predictable.

---

# 22. AI Transcript Formatting

**Target: v1.0**

Settings:

```text
AI Formatting

○ Always Off
● Ask Each Time
○ Always On
```

Default:

> **Ask Each Time**

Possible formatter providers:

## Apple On-Device Language Model

Use Apple's system model when:

- available
- downloaded/enabled
- user selects it
- required macOS version supports it

Show:

> ** Apple Intelligence**  
> On-device · Managed by macOS

## Clide Mini

A small downloadable local model used specifically for transcript formatting.

Requirements:

- optional download
- local
- separate from STT model
- removable
- does not block dictation if unavailable

---

# 23. Ask-Each-Time UX

**Target: v1.0**

Do not show a disruptive modal after every dictation.

Use the floating pill or compact action strip.

```text
Transcript ready

[✨ Format] [Remove Fillers] [Insert]
```

Raw text should always remain available.

---

# 24. Filler Word Removal

**Target: v1.0**

Settings:

```text
Filler Word Removal

○ Always Off
● Ask Each Time
○ Always On
```

Default:

> **Ask Each Time**

Be conservative.

Do not blindly remove words such as:

- like
- so
- well
- you know

unless the selected cleanup strategy can do so safely.

---

# 25. Dashboard

**Target: v1.0**

Clide should have a neat native dashboard, not only a menu bar popover.

Potential content:

```text
Good afternoon

Ready to dictate
Parakeet TDT 0.6B
★★★★★ Excellent for this Mac

Today
2,418 words
23 minutes spoken
18 dictations
100% local

Your Models
Parakeet TDT 0.6B      Active
Whisper Small          Installed
Groq                    Connected

Recent Activity
...
```

Dashboard adapts based on privacy settings.

---

# 26. Local Statistics

**Target: v1.0**

Optional on-device counters:

- words dictated
- dictation count
- speaking duration
- local vs cloud percentage
- model usage
- average transcription latency
- estimated time saved, only if methodology is clearly explained

Statistics remain local unless separately covered by optional developer-data consent.

Users can disable/reset statistics.

---

# 27. Transcript History

**Target: v1.0 if stable; otherwise v1.1**

Features:

- local only
- timestamp
- source application where safely detectable
- model/provider
- duration
- copy
- reinsert
- delete individual entries
- clear all

Hard privacy control:

> **Save Transcript History: Off**

When Off:

- transcript text is not retained after use
- dashboard can still show anonymous local counters if enabled

---

# 28. Sidebar / Navigation

**Target: v1.0**

Suggested:

```text
Clide

⌂ Home
◉ Dictate
⬡ Models
⌁ History
⚙ Settings
```

Developer appears only when Debug Mode is enabled.

Avoid SaaS clutter.

---

# 29. Settings

**Target: v1.0**

## General

- Launch at login
- Appearance
- Motion
- Sound feedback
- Update preferences

## Dictation

- Shortcut
- Push-to-talk / toggle
- Active model
- Silence behavior
- Microphone
- cancellation behavior

## Models

- model storage
- default local model
- local model discovery
- download behavior

## Cloud Providers

- Groq
- Deepgram
- AssemblyAI
- API keys
- provider configuration
- connection testing

## Formatting

- deterministic cleanup
- AI formatting mode
- formatter selection
- filler-word removal
- future text replacements

## Privacy

- transcript history
- local statistics
- developer-data consent
- clear local data
- diagnostics explanation
- Privacy Policy

## Developer

Visible only when Debug Mode is enabled.

---

# 30. Animation / “Dopamine” Philosophy

**Target: v1.0**

Clide should feel satisfying without becoming gamified.

Good examples:

- springy keycaps during onboarding
- responsive microphone waveform
- soft pill expansion
- subtle hover response
- model download progress morphing into Ready
- small checkmark animation after insertion
- hardware stars gently responding on hover
- dashboard statistics smoothly updating
- subtle formatter sparkle
- natural transitions

Avoid:

- confetti
- XP
- streak pressure
- attention-grabbing celebration for normal actions
- slow animations that block work

Clide should feel closer to a polished Apple interaction than a game.

---

# 31. Accessibility / Motion

**Target: v1.0**

Clide should respect:

- macOS Reduce Motion
- keyboard navigation
- VoiceOver
- sufficient contrast
- understandable state changes without relying only on animation/color

Settings may include:

```text
Motion
● System
○ Full
○ Reduced
```

System is default.

---

# 32. Notes Mode

**Target: v1.1 / v1.x**

Freeform voice memos inside Clide.

Potential features:

- longer recordings
- saved notes
- tags
- model selection
- optional formatting
- copy/export
- no mandatory cloud

Do not allow Notes Mode to delay v1.0.

---

# 33. Custom Vocabulary

**Target: v1.1 / v1.x**

Features:

- custom words
- names
- product terminology
- preferred spellings
- per-language vocabulary where supported

---

# 34. Text Replacements

**Target: v1.1 / v1.x**

Examples:

```text
"my email" → user@example.com
"clide app" → Clide
```

Must remain local.

---

# 35. File Mode

**Target: Clide 2.0**

File transcription is intentionally planned as the next major product expansion.

Supported inputs may include:

- `.mp3`
- `.m4a`
- `.wav`
- `.mov`
- `.mp4`
- other formats supported by the media pipeline

Potential output:

- plain text
- Markdown
- SRT
- VTT
- timestamps
- segments
- optional diarization when supported

Potential UX:

> Drop a recording into Clide → choose model → get transcript.

---

# 36. Meeting Mode

**Target: Post-2.0 / Experimental / Maybe Never**

Potential requirements:

- long-running recording
- microphone + system audio
- speaker diarization
- timestamps
- interruption recovery
- speaker renaming
- huge transcript handling
- exports
- session management

FluidAudio makes diarization easier, but does not make Meeting Mode free.

---

# 37. Model / Provider Fallbacks

**Target: v1.1**

Simple optional fallback chain.

```text
Primary: Parakeet local
Fallback: Whisper local
Optional cloud fallback: Groq
```

Cloud fallback must never be silently enabled.

---

# 38. Error Handling

**Target: v1.0**

Friendly, specific errors.

Examples:

- microphone unavailable
- microphone permission denied
- Accessibility permission denied
- model missing
- model failed to load
- provider key invalid
- provider offline
- download failed
- unsupported field
- secure field
- formatter unavailable

Clide should recover whenever practical.

---

# 39. Support for Non-Developers

**Target: v1.0**

Clide is open source, but users should **not** be expected to:

- open Xcode
- read logs
- edit config files
- patch source
- understand Core ML
- debug Accessibility APIs
- manually find model folders
- troubleshoot provider errors from raw JSON

Normal users get:

- understandable error messages
- Retry
- Open Settings
- Test Connection
- Repair Permissions
- Re-download Model
- Copy Diagnostics
- Export Diagnostics
- Reset Component
- Help links

Developer tools are optional, not required.

---

# 40. Update Strategy

**Target: v1.0**

At minimum:

- version display
- GitHub Releases
- changelog
- update-check strategy

Potential later:

- Sparkle or another appropriate update mechanism

Do not silently install updates without user awareness.

---

# 41. Security Requirements

**Target: v1.0**

- Keychain for API keys
- no secrets in logs
- no transcript upload to Clide
- secure-field detection
- signed/notarized builds
- checksummed model downloads
- HTTPS for remote catalog/provider communication
- sanitized diagnostic logs
- explicit cloud-provider warnings
- explicit developer-data consent
- no arbitrary filesystem scanning

---

# 42. Proposed Release Plan

## Clide 0.1 — Sacred Path Prototype

Internal/dev milestone.

Must prove:

> **⌥ + . → speak → local model → text appears in TextEdit**

Includes:

- permissions
- audio capture
- one local STT runtime
- global shortcut
- Accessibility insertion
- clipboard fallback

Nothing else matters until this works.

## Clide 0.2 — Real App Foundation

- WhisperKit
- FluidAudio
- model abstraction
- model IDs
- model manager foundation
- floating pill
- settings architecture
- Keychain
- one cloud provider

## Clide 0.5 — Feature-Complete Alpha

Aim for most v1 features:

- local + BYOK transcription
- model manager
- dashboard
- onboarding
- hardware ratings
- formatting
- filler removal
- statistics
- provider settings
- microphone settings
- animations
- privacy controls
- developer-data consent
- Debug Mode
- diagnostics export

## Clide 0.8 — Public Beta

Focus:

- reliability
- text-field compatibility
- model download robustness
- privacy auditing
- crash fixing
- onboarding testing
- permission recovery
- performance
- accessibility
- UI polish

Feature additions should slow down here.

## Clide 1.0 — Initial Public Release

Expected features:

- native SwiftUI app
- global dictation
- push-to-talk
- toggle recording
- remappable shortcut
- floating pill
- WhisperKit
- FluidAudio / Parakeet
- Apple Speech if stable
- Groq BYOK
- Deepgram BYOK
- AssemblyAI BYOK
- model manager
- stable model IDs
- model metadata
- hardware-fit ratings
- existing-model discovery
- microphone selection
- text insertion
- clipboard fallback
- secure-field behavior
- deterministic cleanup
- optional AI formatting
- Apple local formatter if available
- Clide Mini local formatter
- filler-word settings
- dashboard
- local statistics
- transcript history if it does not delay reliability
- launch at login
- onboarding
- temporary onboarding model
- privacy controls
- optional developer-data sharing
- Debug Mode
- local developer console
- diagnostics export
- polished animations
- Reduce Motion support
- signed/notarized DMG
- GitHub release
- MIT source

## Clide 1.x

Potential features:

- Notes Mode
- custom vocabulary
- text replacements
- better model discovery
- simple fallback chains
- additional STT models
- additional cloud providers
- formatter improvements
- optional per-app preferences
- experimental live typing into target apps

## Clide 2.0 — Files

Major feature:

> **Transcribe existing audio and video files.**

Planned:

- drag-and-drop
- batch/file transcription
- model selection
- progress
- timestamps
- exports
- optional diarization where supported

## Post-2.0 / Experimental

- Meeting Mode
- speaker management
- advanced diarization
- system-audio capture
- true streaming live typing into third-party apps
- advanced per-app behavior
- user-extensible provider system
- other ideas that prove useful without bloating Clide

---

# 43. Explicitly Out of Scope

Unless the project direction changes:

- Clide accounts
- paid Clide subscription
- Clide-hosted transcription credits
- required telemetry
- ad tracking
- cloud transcript storage
- team collaboration suite
- giant plugin marketplace
- arbitrary third-party app patching
- maintaining hacks for other menu-bar/notch apps
- LLM chat assistant
- Grammarly-style writing suite
- gamification systems

---

# 44. Product Rule

Whenever a new feature is proposed, ask:

1. Does this make dictation faster, safer, clearer, or more pleasant?
2. Can a normal non-developer understand it?
3. Does it add meaningful maintenance burden?
4. Does it weaken Clide's privacy model?
5. Does it make the sacred path less reliable?
6. Does it belong in Clide, or is it a separate product hiding inside Clide?

If a feature hurts the sacred path, it waits.

---

# 45. The Clide Standard

Clide 1.0 is ready when this feels boringly reliable:

> **Press ⌥ + . → speak → release → Clide understands → optional cleanup happens → the text lands where it should.**

And when it cannot insert directly:

> Clide clearly explains what happened and safely gives the user their transcript another way.

The app can be cute, animated, and delightful.

But reliability comes first.

use Git or github cli to add the codebase to the repo, carfully inspect the .gitignore files before pushing changes. the repo url is: https://github.com/staraepp/Clide if github CLI isnt logged in, imediatelly give the user instructions on how to sign in before continuing.