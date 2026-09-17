# Implementation plan

The first version was implemented on 15 September 2026. This page records the design decisions and unfinished work. [Development](development.md) describes the current code; [validation](validation.md) records completed checks.

## Scope

Build a standalone Swift daemon that draws borders around macOS application windows. It works alongside `swm`, `skbd`, and `sbar` without requiring a window manager.

The first version covers solid active and inactive colours, round and square borders, configurable width, application filters, display scaling, window tracking, JSONC reloads, and CLI control. A settings app is outside this scope.

The package targets macOS 26, Swift tools 6.2, and Swift 6 language mode. The original development machine ran macOS 27.0 build `26A428` with Swift 6.4. Testing that machine does not establish macOS 26 compatibility.

## References

The original design reviewed these sibling revisions:

| Project | Commit | Reused pattern |
| --- | --- | --- |
| `swm` | `99d3a61d` | Thin CLI, core folders, WindowServer access, IPC |
| `skbd` | `7dfe7491` | Executable/core split and Swift Testing |
| `sbar` | `aa5e36c6` | JSONC configuration, last valid settings, control socket, SkyLight loading |

The package follows their Makefile commands, formatter configuration, and version template. JSONC decoding and watching now come from `StarkConfiguration`; socket transport and messages come from `StarkIPC`. No sibling checkout is required.

Sborders uses the exported sublevel query tested on macOS 27.

## Architecture decisions

`Sborders` contains ArgumentParser commands. `SbordersCore` owns configuration, IPC, platform access, runtime state, and rendering. Tests mirror these folders. Create folders when they have an implementation to hold.

Keep private C signatures and symbol loading in `SkyLight`. Verify integer widths, calling conventions, ownership, and nullable results. A symbol's presence alone does not prove the signature works. Missing required symbols stop startup; missing corner-radius queries use a fixed fallback. The tested backend needed neither a C bridge nor packed Mach messages.

Use AppKit's native event loop with a prohibited activation policy. All window state and drawing belong to the main actor. WindowServer callbacks copy their payloads before returning, then queue typed events. Register notifications before the first scan and reject the daemon's own border windows.

Coalesce updates by window ID and query current snapshots when processing them. Use bounded retries for focus and Space transitions. Keep subscriptions for temporarily hidden windows. The first design proposed generation counters and a coordinator that emitted drawing operations. The implementation instead reconciles current snapshots and leaves native window ownership in `BorderRuntime`.

`BorderGeometry` computes the ring and its drawing strips. `BorderRenderer` draws the ring, and `BorderWindow` owns the backing windows and contexts. Movement reuses drawing. Resizing or changing scale recreates contexts; colour and radius changes redraw. Match the target's level, sublevel, and Spaces, then order the border immediately below it. Release resources on shutdown and partial creation failure.

The default focus mode uses the front application's visible window stack. The optional Accessibility mode requests permission only when selected. Both modes feed the same coordinator. At most one eligible window gets the active style.

Configuration uses one decoder for startup, validation, and reloads. Missing default files use built-in values; missing explicit files fail. Invalid reloads retain valid settings. Runtime overrides never rewrite the file, and a successful reload clears them. See [configuration](configuration.md) for keys and precedence.

CLI clients use an explicit socket and never start a renderer. The server acknowledges a successful stop request before shutting down. Help, version, and validation work without WindowServer. See [command line](cli.md) for commands and socket paths.

## Remaining validation

The first implementation and later tracking changes have automated and desktop results in the [validation record](validation.md). The following still need live checks:

- macOS 26 and the oldest supported compiler.
- Mixed-scale displays, sticky windows, Stage Manager, and Mission Control on macOS 26.
- Sleep/wake, login/logout, and Accessibility focus across applications.
- Sustained movement, resize latency, idle CPU, wakeups, and memory with one, ten, and fifty windows.
- `swm` floating and tiled windows, animated reflows, and keyboard focus.
- A release binary outside the checkout, including its `otool -L` dependencies.

Record OS builds and numerical results. Counters measure submitted work; presentation latency needs a separate measurement.

## Later work

Add uniform corners, gradients, glow, background fill, above-target ordering, and per-application or per-window overrides as separate changes. Each needs geometry or precedence tests and configuration examples.

Treat yabai proxy animations as a separate compatibility project. Add a swm animation interface only if ordinary WindowServer tracking proves insufficient. Review licensing before adapting upstream integration code.
