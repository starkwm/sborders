# sborders implementation plan

The first version was implemented on 15 September 2026. This document preserves the original design, including proposals that changed during implementation. See [development](development.md) and [validation](validation.md) for the implemented behaviour and completed checks.

The implementation uses AppKit's native event loop, the exported sublevel query, and current snapshots when draining coalesced events. It preserves notification subscriptions for temporarily hidden windows. The optional C bridge and packed Mach-message path were unnecessary on the tested system.

## Direction

Build `sborders` as a standalone Swift command-line daemon that draws borders around macOS windows. It should work alongside `swm`, `skbd`, and `sbar`, with no running window manager required.

Use the sibling projects' SwiftPM structure and sbar-style JSONC configuration with explicit commands. Target macOS 26 or later, matching all three projects. Start with Swift tools 6.2 and Swift 6 language mode, matching `skbd` and `sbar`. `swm` now requires Swift 6.4, but sborders has no identified need for that requirement yet.

Use Core Graphics to draw borders and a small private WindowServer backend to track and order them. Keep application logic in Swift. A SwiftUI scene or settings app is unnecessary for this tool.

The first milestone must establish whether the backend works reliably. Package layout, configuration, and drawing are straightforward compared with focus, stacking order, and Spaces.

## Reference projects

The sibling working copies were clean when inspected for the original design.

| Project | Inspected commit | Pattern to follow |
| --- | --- | --- |
| `swm` | `99d3a61d` | Thin CLI, domain folders under the core target, `Platform/WindowServerClient.swift`, IPC |
| `skbd` | `7dfe7491` | Small executable/core split, configuration loader and watcher, Swift Testing |
| `sbar` | `aa5e36c6` | `Commands/`, JSONC decoder and validator, last-valid configuration, local control socket, dynamically loaded SkyLight access |

All three use ArgumentParser, a Makefile, `.swift-format`, version files with templates, and macOS 26 as their deployment target. `swm` names its core target `SwmLib`; the newer `SkbdCore` and `SbarCore` naming is the better fit here.

Follow the short README and focused `docs/` pages. Reuse appropriate sibling utilities after reviewing their tests and dependencies. Keep this package independent of sibling checkout paths and avoid creating a shared package during the first implementation.

## What the JankyBorders review establishes

Reference revision: [JankyBorders a7297ca, version 1.9.0](https://github.com/FelixKratz/JankyBorders/tree/a7297ca7d1933f3a30b12e8f10750e8d84eeee1e).

- Window discovery uses private queries and filters on window attributes, tags, and parent IDs. Notifications cover creation, destruction, moves, resizing, ordering, visibility, focus-related changes, and Spaces. Tracked window IDs also need an explicit notification request. See [events.c](https://github.com/FelixKratz/JankyBorders/blob/a7297ca7d1933f3a30b12e8f10750e8d84eeee1e/src/events.c) and [windows.c](https://github.com/FelixKratz/JankyBorders/blob/a7297ca7d1933f3a30b12e8f10750e8d84eeee1e/src/windows.c).
- Each border is a WindowServer window with a Core Graphics drawing context. Transactions position and order it relative to its target. Moving has a path that avoids repainting; resize changes the shape and redraws. See [border.c](https://github.com/FelixKratz/JankyBorders/blob/a7297ca7d1933f3a30b12e8f10750e8d84eeee1e/src/border.c).
- Sublevel lookup uses packed Mach messages with different message IDs on macOS 26. Its connection-port lookup searches an internal Mach-O symbol. Exported function discovery alone does not cover this dependency. See [window.h](https://github.com/FelixKratz/JankyBorders/blob/a7297ca7d1933f3a30b12e8f10750e8d84eeee1e/src/misc/window.h) and [connection.h](https://github.com/FelixKratz/JankyBorders/blob/a7297ca7d1933f3a30b12e8f10750e8d84eeee1e/src/misc/connection.h).
- Focus can use WindowServer queries or Accessibility. Startup enables the Accessibility path if trust already exists. Therefore, plan a permission-free default and an explicit optional Accessibility mode, then test both. See [main.c](https://github.com/FelixKratz/JankyBorders/blob/a7297ca7d1933f3a30b12e8f10750e8d84eeee1e/src/main.c) and [ax.h](https://github.com/FelixKratz/JankyBorders/blob/a7297ca7d1933f3a30b12e8f10750e8d84eeee1e/src/misc/ax.h).
- Yabai animation support has a separate Mach protocol and proxy-window handling. Ordinary window notifications do not establish animation compatibility. See [yabai.h](https://github.com/FelixKratz/JankyBorders/blob/a7297ca7d1933f3a30b12e8f10750e8d84eeee1e/src/misc/yabai.h).

JankyBorders carries [GPL-3.0](https://github.com/FelixKratz/JankyBorders/blob/a7297ca7d1933f3a30b12e8f10750e8d84eeee1e/LICENSE), while this repository currently carries BSD-3-Clause. The proposed approach is an original implementation retaining BSD, with no copied or mechanically translated upstream implementation. The first implementation follows this direction; see [source provenance](provenance.md) for reused sibling code.

## Project layout

Create folders as their implementations arrive. The tree shows the intended structure, not a requirement to add empty files up front.

```text
Package.swift
Package.resolved
Makefile
.swift-format
.editorconfig
.github/workflows/ci.yml
README.md
Sources/
  Sborders/
    Sborders.swift
    SbordersCommand.swift
    Commands/
    Options/
    Version.swift
    Version.swift.tmpl
  SbordersCore/
    Configuration/
    IPC/
    Platform/
      SkyLight/
      Accessibility/
    Runtime/
      Lifecycle/
      Windows/
      Focus/
      Spaces/
      Displays/
    Rendering/
    Support/
Tests/
  SbordersTests/
  SbordersCoreTests/
    Configuration/
    IPC/
    Platform/
    Runtime/
    Rendering/
docs/
  index.md
  getting-started.md
  configuration.md
  cli.md
  development.md
  implementation-plan.md
examples/
  everyday/config.jsonc
config.schema.json
```

Expose one product, `sborders`, from executable target `Sborders`. Put implementation in `SbordersCore`; tests mirror the relevant folders. Start with ArgumentParser as the only external dependency. Use Darwin sockets as sbar does.

Provide `make build`, `release`, `format`, `lint`, `test`, `clean`, and `bump_version`. Use Swift Testing with XCTest disabled. Pure tests can run in parallel; live WindowServer checks must run separately and serially in a logged-in desktop session.

## Runtime design

### Platform access

`WindowServerClient` wraps discovery, snapshots, notification registration, focus queries, Spaces, and relative ordering. `SkyLightSymbols` owns loaded function pointers and reports capabilities. Keep raw IDs, flags, symbol names, callback payloads, and Mach details inside `Platform`.

Use dynamically loaded C function signatures where Swift can represent them correctly. Verify integer widths, calling conventions, Core Foundation ownership, and nullable results for every declaration. Symbol presence does not prove a signature or behaviour is correct.

For packed Mach messages, use an explicitly encoded buffer with checked offsets and sizes. Do not assume Swift struct layout matches a packed C struct. If an indispensable ABI cannot be expressed safely in Swift, document that result before choosing a minimal C bridge target. Keep that decision within the prototype.

Required backend failures should stop startup with a useful error. Optional corner-radius discovery can fall back to a documented fixed radius. Do not silently continue with incorrect window ordering when sublevel access fails. Investigate a simpler working query before adopting internal symbol-table parsing.

### State and event handling

`BorderRuntime` owns lifecycle. A window registry stores snapshots keyed by window ID and an internal generation so queued events cannot affect a reused ID. Each snapshot includes owner PID, application identity, frame, level and sublevel, Space membership, visibility, and eligibility.

`WindowEventSource` copies and validates callback bytes before returning. It submits typed events to one serial owner, initially the main actor. Register notifications before the initial scan, then reconcile events received during discovery. Refresh per-window notification subscriptions as the registry changes.

`BorderCoordinator` turns snapshots and resolved settings into create, move, redraw, reorder, hide, and destroy operations. Keep these decisions testable with fake platform access. Destroy and hide events invalidate queued drawing work. Reject the daemon's own border windows before normal discovery.

Coalesce repeated updates per window within a run-loop turn. Keep the latest frame and process lifecycle changes in order. Use bounded retries when focus or Space metadata is temporarily unavailable. Reconcile on startup, Space changes, display changes, and session wake. Avoid a continuous global scan or an idle animation timer.

Start with serial rendering and explicit resource ownership. Introduce background drawing only if measurement identifies it as a bottleneck; pass immutable drawing inputs and reject obsolete results.

### Drawing and ordering

`BorderGeometry` computes the outer bounds and inner cutout in points. `BorderRenderer` draws into a CGContext. `BorderWindow` owns its window, context, and any backend connection. Release each resource on shutdown and on partial creation failure.

Pure movement updates position without repainting. Size, colour, radius, and display-scale changes invalidate drawing. Reuse paths where their inputs are unchanged. Make border windows transparent, nonactivating, click-through, and shadowless.

Match the target's level and sublevel, then order immediately below it by default. Preserve membership in the target's Spaces, including sticky windows. Sbar's always-visible custom Space is unsuitable for these per-window borders. Hide borders for minimised, hidden, and native fullscreen windows, then reconcile on return. Verify Mission Control and Stage Manager behaviour during live testing.

### Focus

Start with a WindowServer focus resolver that checks the front application's eligible windows on the active display and Space. A front application alone is insufficient when it owns several windows. Test same-application focus changes and multiple displays explicitly.

Offer `focusMode: "accessibility"` as an optional mode when needed. Request trust only for that explicit mode and report denied permission clearly. Both modes feed the same coordinator. At most one eligible window receives the active style; unresolved focus clears the active assignment after the bounded retry.

## Configuration and commands

Resolve `~/.config/sborders/config.jsonc` before `config.json`, with `--config` selecting an explicit file. Support comments and trailing commas through one shared decoder used by startup, reload, and `validate`. Use camelCase keys and sbar's `#RRGGBB` or `#RRGGBBAA` colours, with alpha last.

Proposed initial configuration:

```jsonc
{
  "enabled": true,
  "width": 4,
  "style": "round",
  "activeColor": "#E1E3E4",
  "inactiveColor": "#00000000",
  "focusMode": "windowServer",
  "includeApps": [],
  "excludeApps": []
}
```

An empty include list allows all eligible applications; exclusion wins. Use exact bundle identifiers, with an explicit process-name matcher for applications without one. Do not silently treat a string as both. Define the matcher object in the schema before implementing filtering.

Use the display's scale automatically. Start with `round` and `square`; add `uniform` in the styling milestone. Specify geometry and narrow-window behaviour in tests. Validate finite positive widths with a documented upper bound, colours, enums, unknown keys, and duplicate keys. Ship a schema and validate every example with the real CLI.

Missing default configuration uses built-in defaults. Missing explicit files and invalid startup files fail with a nonzero status. After startup, invalid edits retain the last valid configuration and expose the error through diagnostics. Watch the parent directory so atomic editor saves and later file creation work. Treat disappearance during a save as a reload failure until a valid replacement arrives.

Proposed commands:

```sh
sborders                         # Same as start, remains in the foreground
sborders start --config /path/to/config.jsonc
sborders validate --config /path/to/config.jsonc
sborders query --windows
sborders query --config
sborders query --diagnostics
sborders reload
sborders set activeColor '#89B4FA'
sborders set enabled false
sborders stop
```

Client commands accept `--socket`. Default to `control.sock` beside the resolved configuration, following sbar. Use a lock, same-user checks, restrictive socket permissions, bounded newline-delimited JSON messages, and explicit errors. Client invocations never start another renderer. `validate`, help, and version must work without connecting to WindowServer.

Runtime `set` values do not rewrite the file. Resolve defaults, then file settings, then runtime overrides. A successful explicit or watched reload clears overrides and adopts the file; failed reloads change neither. Apply configuration changes atomically and redraw only affected borders. Stop acknowledges the request, drains callbacks, destroys borders, and removes its owned socket.

## Delivery milestones

### 1. Prove the backend

- Add the smallest SwiftPM executable/core setup, format configuration, and a developer probe.
- Discover real window IDs, create one border, track it, and destroy it cleanly.
- Establish notification delivery and any required WindowServer event-port draining.
- Verify focus, level and sublevel, relative ordering, Spaces, pointer signatures, and resource ownership.
- Test on macOS 26 and separately on the current Mac, which reports macOS 27.0 build `26A428` with Swift 6.4.

Exit when one border follows a target through movement, resize, focus change, and a Space transition without intercepting input or remaining after target closure. Record the OS builds and any unsupported backend features. If ordering cannot be made reliable, resolve that before expanding the daemon. A passing check on macOS 27 does not establish macOS 26 support.

### 2. Track windows reliably

- Add the registry, eligibility policy, coordinator, focus resolver, and lifecycle handling.
- Support existing and newly created windows across displays and Spaces.
- Implement solid active and inactive styles, round and square geometry, automatic scale changes, and event coalescing.
- Add deterministic tests for lifecycle races, duplicate notifications, window ID reuse, invalid snapshots, and cleanup.

Exit when ordinary daily use leaves no orphan borders after closing, hiding, minimising, fullscreen transitions, application exit, or sleep and wake. Confirm that unsupported windows and the daemon's own windows are excluded.

### 3. Add configuration and control

- Implement the confirmed JSONC interface, schema, watcher, validator, filters, socket, and commands.
- Test precedence, atomic application, malformed messages, peer checks, partial reads, startup contention, and stale sockets.
- Add the optional Accessibility focus resolver and permission diagnostics.
- Add concise documentation and an everyday example.

Exit when configuration can be validated without a GUI, edited while running, queried, overridden, reloaded, and stopped with predictable errors and no duplicate renderer.

### 4. Validate the first release

- Add CI for formatting and Swift Testing on a runner compatible with the chosen toolchain.
- Test the oldest supported compiler and OS separately from the macOS 27 development environment.
- Measure idle CPU, wakeups, memory, move and resize latency, and repaint counts with one, ten, and fifty windows.
- Compare the same release-build scenarios with the pinned JankyBorders version, running one border daemon at a time.
- Check `swm` floating and tiled windows, animated reflows, keyboard focus, mixed-scale displays, Mission Control, Stage Manager, and login/logout.
- Prepare version stamping and a standalone release binary. Check release binary dependencies with `otool -L` and test outside the checkout.

Exit when automated checks pass and the live test record names the tested OS versions and remaining limitations. Set numerical performance budgets from the prototype baseline; do not claim Swift is faster without measurements.

### 5. Extend styling and compatibility

Add uniform corners, gradients, glow, optional background fill, above-target ordering, and per-application or per-window overrides as separate changes with geometry and precedence tests. Document migration examples from JankyBorders colours and settings.

Treat yabai proxy animations as a separate compatibility project. Add a swm-specific animation interface only if normal WindowServer tracking proves insufficient. Recheck the licensing direction before adapting upstream integration code.

## First-release boundary

The first release covers solid active and inactive borders, round and square styles, configurable width, application inclusion and exclusion, automatic display scaling, window lifecycle, JSONC reload, and CLI control. It remains independent of a particular window manager.

Full JankyBorders styling parity and its yabai animation protocol follow later. The original prototype needed to establish sublevel access, focus reliability without Accessibility, callback delivery and shutdown, and behaviour across supported macOS releases.

The first version implements the first-release boundary. Remaining platform validation and later styling work are listed in [development](development.md).
