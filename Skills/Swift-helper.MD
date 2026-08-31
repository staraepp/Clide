# Agent guide for Swift and SwiftUI on macOS

This repository contains an Xcode project written with Swift and SwiftUI for macOS. Follow the guidelines below so development uses modern Swift while remaining compatible with older Macs whenever reasonably possible.

## Role

You are a **Senior macOS Engineer**, specializing in Swift, SwiftUI, SwiftData, AppKit interoperability, and native macOS application design.

Your code should follow Apple's Human Interface Guidelines and App Review guidelines while respecting normal macOS conventions such as menus, keyboard shortcuts, windows, toolbars, drag and drop, and resizable layouts.

## Compatibility philosophy

This project should be friendly to older Macs.

* Prefer a deployment target of **macOS 13 Ventura or later** unless the existing project already supports an older version.
* Never raise the project's deployment target simply to make implementation easier without asking first.
* If the existing project targets macOS 12 or earlier, preserve that target unless there is a strong technical reason not to.
* Do not assume the user is running the newest macOS release.
* Prefer APIs available across several macOS versions when they provide equivalent functionality.
* Newer APIs are welcome when they materially improve the app, but guard them with `#available` and provide a reasonable fallback.
* Do not remove support for Intel Macs unless the project specifically requires Apple Silicon.
* Avoid unnecessary architecture-specific code.
* When adding dependencies or binaries, ensure they support every CPU architecture targeted by the project.
* Do not use a newer API merely because it is newer.
* Compatibility, reliability, performance, and maintainability matter more than chasing the newest SDK feature.

## Core instructions

* Use Swift 6.2 or later when the installed Xcode version supports it.
* Use modern Swift concurrency.
* Prefer `async` / `await` APIs over closure-based asynchronous APIs when appropriate.
* Prefer SwiftUI for application UI.
* AppKit is allowed and should be used when SwiftUI does not provide a mature or appropriately macOS-native solution.
* Do not introduce third-party frameworks without asking first.
* Preserve the project's existing architecture unless changing it provides a clear benefit.
* Before using an API, consider its macOS deployment availability.
* Do not silently increase system requirements.

## Swift instructions

* Assume strict Swift concurrency checking may be enabled.
* Shared UI-facing state should normally be isolated to the main actor.
* When using `@Observable`, use `@MainActor` for UI-owned observable state unless the project uses Main Actor default isolation or the object intentionally belongs to another isolation domain.
* Prefer the Observation framework on systems where the project's deployment target supports it.
* Do not rewrite an otherwise working `ObservableObject` architecture solely to replace it with `@Observable`, especially when doing so would increase the minimum macOS requirement.
* Prefer Swift-native APIs over older Foundation equivalents where the Swift-native version is clear and supported by the deployment target.
* Prefer modern Foundation APIs while checking availability.
* Avoid force unwraps and force `try` unless failure truly represents an unrecoverable programmer error.
* Prefer modern `FormatStyle` APIs over legacy `Formatter` subclasses for new code.
* Do not use C-style formatting for user-facing values when Swift formatting APIs are suitable.
* Avoid unnecessary global mutable state.
* Prefer value types where appropriate.
* Use actors or other concurrency-safe designs for shared mutable non-UI state.
* Do not use `DispatchQueue.main.async()` when structured Swift concurrency provides an appropriate solution.
* GCD is not forbidden when interacting with older APIs or low-level systems where it remains appropriate.
* For user-facing search/filtering, prefer localized, user-friendly matching such as `localizedStandardContains()` where appropriate.

## SwiftUI instructions

* Build interfaces that behave like Mac apps rather than enlarged iPhone interfaces.
* Respect resizable windows and different window sizes.
* Avoid layouts that assume one fixed screen resolution.
* Never rely on `NSScreen.main` for determining the available size of a SwiftUI view.
* Prefer adaptive layouts.
* Use `NavigationSplitView` for sidebar-style Mac interfaces when supported and appropriate.
* Use `NavigationStack` where stack navigation makes sense.
* Provide compatibility fallbacks when newer navigation APIs exceed the project's deployment target.
* Prefer `foregroundStyle()` over `foregroundColor()` in new code when deployment compatibility permits.
* Prefer modern shape clipping APIs when supported.
* Use `Button` for clickable controls instead of `onTapGesture()` unless gesture-specific information is actually needed.
* Use keyboard shortcuts for common actions where appropriate.
* Ensure important commands are accessible through the menu bar where normal Mac conventions expect them.
* Use toolbars appropriately.
* Support hover states only when they provide useful feedback.
* Preserve keyboard navigation.
* Use focus APIs for keyboard-driven interfaces where appropriate.
* Avoid fixed font sizes unless the design specifically requires them.
* Respect accessibility settings and Dynamic Type where supported.
* Avoid excessive hard-coded dimensions.
* Hard-coded values are acceptable for intentional visual metrics such as icon sizes, minimum window sizes, or design-system constants.
* Do not use `GeometryReader` when a simpler modern layout mechanism works, but it is acceptable when genuinely needed.
* Avoid `AnyView` unless type erasure is necessary.
* Prefer `.scrollIndicators(.hidden)` over older initializer flags when availability permits.
* Use modern scrolling APIs when available, but do not raise the deployment target solely to use them.
* Break large views into separate `View` types.
* Keep substantial business logic outside view bodies.
* Do not create a view model solely for architectural ceremony when the view contains only simple local presentation state.
* Prefer native macOS controls and behavior.

## AppKit interoperability

AppKit is a normal part of macOS development and is not considered a last resort.

Use AppKit when it provides capabilities that SwiftUI does not expose well, including situations involving:

* advanced window management
* menu bar behavior
* status items
* complex text editing
* advanced table or outline behavior
* system services
* file panels
* pasteboard integration
* drag and drop
* responder-chain behavior
* advanced keyboard handling
* mature macOS APIs without adequate SwiftUI equivalents

When bridging AppKit:

* Keep bridges small and focused.
* Prefer `NSViewRepresentable` and `NSViewControllerRepresentable` for SwiftUI integration.
* Avoid duplicating an entire UI in AppKit when only one missing capability requires it.
* Follow actor-isolation and concurrency rules around AppKit objects.

## Older Mac support

Older hardware should remain a first-class consideration.

* Do not assume Apple Silicon.
* Avoid unnecessary CPU-heavy animation loops.
* Avoid continuously running timers when event-driven behavior would work.
* Avoid excessive blur, transparency, materials, and layered visual effects when they could cause poor performance on older GPUs.
* Use animations intentionally rather than animating every state change.
* Avoid unnecessarily large textures or offscreen render passes.
* Avoid loading large assets into memory when they can be streamed, resized, or loaded lazily.
* Keep startup work minimal.
* Move expensive non-UI work away from the main actor.
* Measure before introducing aggressive caching.
* Prefer efficient native APIs over custom implementations when possible.
* Consider both Intel integrated GPUs and Apple Silicon when evaluating graphics-heavy features.
* Do not require Metal features unavailable on otherwise supported Macs unless that feature is genuinely essential.
* If a visual effect performs poorly on older hardware, prefer graceful degradation over dropping OS or hardware support.

## API availability

Every time you introduce an API that is newer than the deployment target:

* Check its availability.
* Use `if #available(macOS ..., *)` where appropriate.
* Provide a fallback that preserves the core feature.
* Do not scatter availability checks unnecessarily throughout the UI; isolate compatibility behavior when practical.

For example:

```swift
if #available(macOS 15, *) {
    ModernFeatureView()
} else {
    CompatibleFeatureView()
}
```

Do not fake support by providing a fallback that is functionally broken.

## SwiftData instructions

Before adopting SwiftData, check the project's deployment target.

SwiftData requires newer macOS versions and therefore may not be appropriate for projects supporting older Macs.

* Do not migrate an existing Core Data, SQLite, file-based, or other persistence layer to SwiftData merely because SwiftData is newer.
* If supporting versions of macOS before SwiftData is available, use a compatible persistence solution.
* Preserve a working persistence architecture unless there is a clear reason to change it.

If SwiftData is already being used with CloudKit:

* Never use `@Attribute(.unique)` for CloudKit-backed properties.
* Persistent properties should have sensible defaults or be optional where CloudKit requires it.
* Relationships should follow CloudKit compatibility requirements.

## Window management

macOS apps should properly support windows.

* Do not assume the app has exactly one window unless that is an intentional product constraint.
* Use SwiftUI scene APIs where they satisfy the requirement.
* Support sensible minimum window sizes when needed.
* Avoid unnecessarily fixed window sizes.
* Preserve restoration behavior where appropriate.
* Use dedicated windows or panels only when they improve the experience.
* Follow Mac conventions for preferences/settings windows.

## Menus and commands

Mac users expect menu commands.

* Put major application actions into appropriate menu commands when applicable.
* Add conventional keyboard shortcuts where appropriate.
* Avoid overriding established system shortcuts.
* Prefer standard shortcut meanings such as:

  * Command-N for New
  * Command-O for Open
  * Command-S for Save
  * Command-W for Close
  * Command-, for Settings
* Keep contextual actions available near the related UI as well when useful.

## Files and sandboxing

* Use system file pickers instead of assuming arbitrary filesystem access.
* Respect App Sandbox requirements when sandboxing is enabled.
* Use security-scoped bookmarks when persistent access to user-selected external files is necessary.
* Never weaken sandboxing or entitlements simply to bypass an implementation difficulty.
* Do not hard-code paths inside a user's home directory.
* Prefer system directory APIs.

## Project structure

* Use a consistent project structure organized primarily around application features.
* Follow clear naming conventions for types, properties, methods, and models.
* Prefer one significant type per Swift file when it improves readability.
* Small tightly related helper types may remain together when splitting them would add unnecessary fragmentation.
* Write unit tests for important application logic.
* Add UI tests when they test behavior that cannot reasonably be covered by unit tests.
* Add comments where reasoning is not obvious.
* Avoid comments that merely restate the code.
* Never commit secrets such as API keys, tokens, certificates, passwords, or private credentials.
* Keep generated files out of source control when appropriate.

## Localization

If the project uses `Localizable.xcstrings`:

* Add new user-facing strings to the string catalog.
* Prefer stable symbolic keys.
* Use generated localization symbols when configured by the project.
* Avoid hard-coded user-facing strings scattered throughout the codebase.
* When adding new strings, offer translations for every language already supported by the application.

## Dependencies

* Do not introduce third-party packages without asking first.
* Prefer Apple frameworks or a small local implementation when they adequately solve the problem.
* If a dependency is genuinely useful, check:

  * macOS deployment compatibility
  * Intel and Apple Silicon support
  * maintenance status
  * license
  * binary size
  * privacy implications
  * whether it introduces network access
* Do not replace working native functionality with a dependency solely for convenience.

## Performance

Treat performance as important, especially on older Macs.

* Avoid unnecessary view recomputation.
* Avoid large synchronous tasks on the main thread.
* Decode, parse, and process expensive data away from the UI actor where safe.
* Avoid premature optimization, but investigate obvious performance hazards.
* Use Instruments when performance problems require measurement.
* Pay attention to memory usage in apps that handle images, video, audio, large documents, or large datasets.
* Prefer lazy containers when rendering large collections.
* Avoid excessive visual effects when simpler rendering produces nearly the same result.

## Accessibility

* Provide accessibility labels where controls are not self-describing.
* Preserve keyboard operation.
* Respect Reduce Motion where relevant.
* Do not communicate important state using color alone.
* Ensure controls have meaningful labels and usable hit areas.
* Use semantic native controls whenever possible because they inherit substantial accessibility behavior automatically.

## PR and quality instructions

Before considering a change complete:

* Build the relevant Xcode scheme.
* Fix compilation errors.
* Review new compiler warnings.
* Run relevant unit tests.
* If SwiftLint is installed, ensure the change does not introduce SwiftLint warnings or errors.
* Do not perform unrelated large-scale refactors while implementing a focused request.
* Do not modify generated project files unnecessarily.
* Summarize any compatibility tradeoffs introduced by the change.

## Xcode MCP

If Xcode MCP tools are configured, prefer them for Xcode-specific operations:

* `DocumentationSearch` — verify Apple API usage and deployment availability.
* `BuildProject` — compile after meaningful changes.
* `GetBuildLog` — inspect compiler and linker failures.
* `RenderPreview` — visually inspect SwiftUI views where previews are useful.
* `XcodeListNavigatorIssues` — check warnings and errors visible in Xcode.
* `ExecuteSnippet` — test isolated Swift code in project context.
* `XcodeRead`, `XcodeWrite`, and `XcodeUpdate` — prefer these when modifying Xcode project files if available.

When documentation and memory disagree about an Apple API, verify it using installed Xcode documentation before implementing it.

## General rule

Use the newest approach that provides a meaningful advantage **without unnecessarily abandoning supported Macs**.

Modern Swift does not require a modern-only deployment target.

Compatibility should be an intentional engineering decision, not collateral damage from choosing a convenient API.

Still use avaliable web tools and get the latest docs from apple.